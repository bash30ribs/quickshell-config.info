/*
 * QDeck: Real-time PipeWire audio analyzer with autocorrelation BPM locking for QuickShell.
 * Ensures wave/animation pace only speeds up when sustained musical tempo matches that pace.
 * Outputs smoothed frames (~47 Hz when audio active): "<level> <bass> <beat> <bps>\n"
 */
#define _POSIX_C_SOURCE 200809L

#include <fftw3.h>
#include <math.h>
#include <pulse/mainloop-signal.h>
#include <pulse/pulseaudio.h>
#include <signal.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <unistd.h>

#define SAMPLE_RATE 48000
#define FFT_SIZE 1024
#define HOP_SIZE 1024
#define HOP_HZ ((float)SAMPLE_RATE / (float)HOP_SIZE) /* 46.875 Hz */
#define BINS (FFT_SIZE / 2 + 1)

/* 4.1s onset-strength history ring for autocorrelation tempo detection */
#define OSS_LEN 192
#define LAG_MIN 14 /* ~200.9 BPM ceiling */
#define LAG_MAX 53 /* ~53.1 BPM floor */

typedef struct {
    pa_mainloop *mainloop;
    pa_mainloop_api *api;
    pa_context *ctx;
    pa_stream *stream;
    char current_source[512];

    float ring[FFT_SIZE];
    int ring_pos;
    int hop_accum;

    float hann[FFT_SIZE];
    float *fft_in;
    fftwf_complex *fft_out;
    fftwf_plan plan;
    float prev_log_mag[BINS];

    float oss_ring[OSS_LEN];
    int oss_pos;
    int oss_filled;
    int hop_counter;
    float bpm_hist[5];
    int bpm_hist_pos;
    int bpm_hist_count;
    int confirm_streak;

    float rms_peak;
    float bass_peak;
    float beat_flux_mean;

    float level_env;
    float bass_env;
    float beat_env;
    float confirmed_bps; /* beats per second (1.0 = 60 BPM, 2.0 = 120 BPM) */
    float tempo_conf;

    double last_onset_sec;
    double last_emit_sec;
    int silent_frames;
    int settled_emitted;
} App;

static float clampf(float v, float lo, float hi) {
    if (v < lo) return lo;
    if (v > hi) return hi;
    return v;
}

static double now_monotonic(void) {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return (double)ts.tv_sec + (double)ts.tv_nsec * 1e-9;
}

static void on_sig(pa_mainloop_api *a, pa_signal_event *e, int sig, void *userdata) {
    (void)e;
    (void)sig;
    App *app = (App *)userdata;
    if (app && app->mainloop) {
        pa_mainloop_quit(app->mainloop, 0);
    } else if (a) {
        a->quit(a, 0);
    }
}

static float median5(const float *arr, int count) {
    float tmp[5];
    int n = count < 5 ? count : 5;
    if (n <= 0) return 72.0f;
    for (int i = 0; i < n; i++) tmp[i] = arr[i];
    for (int i = 0; i < n - 1; i++) {
        for (int j = i + 1; j < n; j++) {
            if (tmp[j] < tmp[i]) {
                float t = tmp[i];
                tmp[i] = tmp[j];
                tmp[j] = t;
            }
        }
    }
    return tmp[n / 2];
}

/* Estimate true periodic BPM from sliding 4.1s bass/low-mid onset strength signal */
static void update_tempo_estimate(App *app) {
    int n = app->oss_filled < OSS_LEN ? app->oss_filled : OSS_LEN;
    if (n < 96) {
        /* Wait for at least ~2 seconds of rhythmic history before trusting fast paces */
        app->tempo_conf = 0.0f;
        return;
    }

    float sig[OSS_LEN];
    double mean = 0.0;
    int start = (app->oss_pos - n + OSS_LEN) % OSS_LEN;
    for (int i = 0; i < n; i++) {
        float v = app->oss_ring[(start + i) % OSS_LEN];
        sig[i] = v;
        mean += (double)v;
    }
    mean /= (double)n;

    double r0 = 0.0;
    for (int i = 0; i < n; i++) {
        sig[i] -= (float)mean;
        r0 += (double)sig[i] * (double)sig[i];
    }
    /* Ignore beatless drones/LFO swells whose onset-strength modulation is tiny */
    float oss_rms = sqrtf((float)(r0 / (double)n));
    if (r0 < 1e-4 || oss_rms < 0.20f) {
        app->tempo_conf = 0.0f;
        if (app->confirm_streak > 0) app->confirm_streak--;
        app->confirmed_bps += (1.10f - app->confirmed_bps) * 0.10f;
        return;
    }

    double acf[OSS_LEN / 2 + 1];
    int max_acf_lag = n / 2;
    if (max_acf_lag > LAG_MAX * 2 + 2) max_acf_lag = LAG_MAX * 2 + 2;
    for (int lag = 1; lag <= max_acf_lag; lag++) {
        double sum = 0.0;
        int pairs = n - lag;
        for (int i = 0; i < pairs; i++) {
            sum += (double)sig[i] * (double)sig[i + lag];
        }
        /* Unbiased scaling adjusted smoothly toward longer lags */
        acf[lag] = (sum * (double)n / (double)pairs) / r0;
    }

    int best_lag = 38; /* ~74 BPM default */
    double best_score = -1.0;
    double best_raw = 0.0;

    for (int lag = LAG_MIN; lag <= LAG_MAX && lag <= max_acf_lag; lag++) {
        double r = acf[lag];
        if (r <= 0.0) continue;

        /* Harmonic reinforcement at 2x and 3x lag rewards true periodic repetition */
        double h2 = (lag * 2 <= max_acf_lag && acf[lag * 2] > 0.0) ? acf[lag * 2] : 0.0;
        double h3 = (lag * 3 <= max_acf_lag && acf[lag * 3] > 0.0) ? acf[lag * 3] : 0.0;
        double score = r + 0.35 * h2 + 0.15 * h3;

        /* Only suppress double-time half-lag if double period (2*lag) is noticeably stronger (kick+snare/hat asymmetry) */
        if (lag * 2 <= LAG_MAX && acf[lag * 2] > r * 1.06) {
            score *= 0.72;
        }

        /* Gentle perceptual tempo prior centered around 108 BPM */
        float bpm_cand = (HOP_HZ * 60.0f) / (float)lag;
        float oct_dist = log2f(bpm_cand / 108.0f);
        double prior = 1.0 - 0.04 * (double)(oct_dist * oct_dist);
        score *= prior;

        if (score > best_score) {
            best_score = score;
            best_lag = lag;
            best_raw = r;
        }
    }

    /* Parabolic interpolation around best_lag for smooth fractional BPM resolution */
    float frac_lag = (float)best_lag;
    if (best_lag > LAG_MIN && best_lag < LAG_MAX && best_lag + 1 <= max_acf_lag) {
        double y0 = acf[best_lag - 1];
        double y1 = acf[best_lag];
        double y2 = acf[best_lag + 1];
        double denom = 2.0 * (y0 - 2.0 * y1 + y2);
        if (fabs(denom) > 1e-6) {
            float delta = clampf((float)((y0 - y2) / denom), -0.5f, 0.5f);
            frac_lag += delta;
        }
    }

    float raw_conf = clampf((float)best_raw, 0.0f, 1.0f);
    app->tempo_conf = raw_conf;

    /* Only accept tempo & allow pace upgrades when periodicity confidence confirms a steady rhythm */
    if (raw_conf >= 0.26f) {
        float est_bpm = clampf((HOP_HZ * 60.0f) / frac_lag, 54.0f, 192.0f);
        app->bpm_hist[app->bpm_hist_pos] = est_bpm;
        app->bpm_hist_pos = (app->bpm_hist_pos + 1) % 5;
        if (app->bpm_hist_count < 5) app->bpm_hist_count++;
        if (app->confirm_streak < 20) app->confirm_streak++;

        if (app->confirm_streak >= 2) {
            float med_bpm = median5(app->bpm_hist, app->bpm_hist_count);
            float target_bps = clampf(med_bpm / 60.0f, 0.90f, 3.20f);
            if (target_bps > app->confirmed_bps)
                app->confirmed_bps += (target_bps - app->confirmed_bps) * 0.22f;
            else
                app->confirmed_bps += (target_bps - app->confirmed_bps) * 0.16f;
        }
    } else {
        /* Beatless / ambient / sparse speech: decay smoothly back to relaxed slow pace */
        if (app->confirm_streak > 0) app->confirm_streak--;
        app->confirmed_bps += (1.10f - app->confirmed_bps) * 0.10f;
    }
}

static void process_hop(App *app) {
    double sum_sq = 0.0;
    for (int i = 0; i < FFT_SIZE; i++) {
        int idx = (app->ring_pos + i) % FFT_SIZE;
        float s = app->ring[idx];
        sum_sq += (double)s * (double)s;
        app->fft_in[i] = s * app->hann[i];
    }

    float rms = sqrtf((float)(sum_sq / (double)FFT_SIZE));
    fftwf_execute(app->plan);

    double t = now_monotonic();

    /* Silence gate */
    if (rms < 2.5e-5f) {
        app->silent_frames++;
        app->level_env *= 0.70f;
        app->bass_env *= 0.67f;
        app->beat_env *= 0.61f;
        app->confirmed_bps += (1.10f - app->confirmed_bps) * 0.08f;
        app->confirm_streak = 0;
        app->oss_ring[app->oss_pos] = 0.0f;
        app->oss_pos = (app->oss_pos + 1) % OSS_LEN;

        if (app->silent_frames < 30 || !app->settled_emitted) {
            if ((t - app->last_emit_sec) >= 0.020) {
                app->last_emit_sec = t;
                if (app->level_env < 0.004f && app->bass_env < 0.004f && app->beat_env < 0.004f) {
                    printf("0.000 0.000 0.000 1.100\n");
                    app->settled_emitted = 1;
                } else {
                    printf("%.3f %.3f %.3f %.3f\n", app->level_env, app->bass_env, app->beat_env, app->confirmed_bps);
                }
                fflush(stdout);
            }
        }
        return;
    }

    app->silent_frames = 0;
    app->settled_emitted = 0;

    /* Extract sub-bass energy (bins 1..4) and low/mid beat onset flux (bins 1..14: ~47-656Hz, kick-weighted) */
    float bass_energy = 0.0f;
    float beat_flux = 0.0f;
    for (int k = 1; k <= 20 && k < BINS; k++) {
        float re = app->fft_out[k][0];
        float im = app->fft_out[k][1];
        float mag = sqrtf(re * re + im * im);
        float logm = log1pf(mag * 1.5f);

        if (k <= 4) {
            bass_energy += mag;
        }

        float diff = logm - app->prev_log_mag[k];
        if (diff > 0.0f && k <= 14) {
            /* Weight fundamental kick & bassline strongly so hi-hat ticks do not fake fast tempo */
            float w = (k <= 4) ? 2.4f : ((k <= 8) ? 1.1f : 0.45f);
            beat_flux += w * diff;
        }
        app->prev_log_mag[k] = logm;
    }
    bass_energy /= 4.0f;

    /* Push onset strength into 4.1s autocorrelation ring */
    app->oss_ring[app->oss_pos] = beat_flux;
    app->oss_pos = (app->oss_pos + 1) % OSS_LEN;
    if (app->oss_filled < OSS_LEN) app->oss_filled++;

    app->hop_counter++;
    if ((app->hop_counter % 8) == 0) {
        update_tempo_estimate(app);
    }

    /* Adaptive rolling peak envelope */
    app->rms_peak = fmaxf(rms, fmaxf(0.012f, app->rms_peak * 0.993f));
    app->bass_peak = fmaxf(bass_energy, fmaxf(0.45f, app->bass_peak * 0.992f));

    float norm_level = clampf(powf(rms / app->rms_peak, 0.72f), 0.0f, 1.0f);
    float norm_bass = clampf(powf(bass_energy / app->bass_peak, 0.78f), 0.0f, 1.0f);

    if (norm_level > app->level_env)
        app->level_env += (norm_level - app->level_env) * 0.62f;
    else
        app->level_env += (norm_level - app->level_env) * 0.22f;

    if (norm_bass > app->bass_env)
        app->bass_env += (norm_bass - app->bass_env) * 0.70f;
    else
        app->bass_env += (norm_bass - app->bass_env) * 0.26f;

    /* Beat kick gate gated sensibly to confirmed tempo half-period so slow songs cannot multi-trigger */
    app->beat_flux_mean = app->beat_flux_mean * 0.91f + beat_flux * 0.09f;
    app->beat_env *= 0.68f;
    float min_beat_gap = clampf(0.55f / fmaxf(app->confirmed_bps, 0.85f), 0.20f, 0.58f);
    if (beat_flux > fmaxf(app->beat_flux_mean * 1.72f + 0.18f, 1.05f) && (t - app->last_onset_sec) >= (double)min_beat_gap) {
        app->last_onset_sec = t;
        app->beat_env = fminf(1.0f, app->beat_env + 0.90f);
    }

    if ((t - app->last_emit_sec) >= 0.020) {
        app->last_emit_sec = t;
        if (printf("%.3f %.3f %.3f %.3f\n", app->level_env, app->bass_env, app->beat_env, app->confirmed_bps) < 0 || fflush(stdout) != 0) {
            if (app->mainloop) pa_mainloop_quit(app->mainloop, 0);
        }
    }
}

static void on_stream_read(pa_stream *s, size_t length, void *userdata) {
    App *app = (App *)userdata;
    (void)length;

    const void *data = NULL;
    size_t nbytes = 0;
    while (pa_stream_peek(s, &data, &nbytes) == 0 && nbytes > 0) {
        if (data) {
            const float *samples = (const float *)data;
            size_t nsamples = nbytes / sizeof(float);
            for (size_t i = 0; i < nsamples; i++) {
                app->ring[app->ring_pos] = samples[i];
                app->ring_pos = (app->ring_pos + 1) % FFT_SIZE;
                app->hop_accum++;
                if (app->hop_accum >= HOP_SIZE) {
                    app->hop_accum = 0;
                    process_hop(app);
                }
            }
        }
        pa_stream_drop(s);
    }
}

static void on_stream_state(pa_stream *s, void *userdata) {
    (void)userdata;
    if (pa_stream_get_state(s) == PA_STREAM_FAILED) {
        fprintf(stderr, "qdeck-audio-sync: stream failed\n");
    }
}

static void connect_monitor_stream(App *app, const char *sink_name) {
    if (!sink_name || !sink_name[0]) return;

    char mon_name[512];
    snprintf(mon_name, sizeof(mon_name), "%s.monitor", sink_name);
    if (strcmp(app->current_source, mon_name) == 0 && app->stream) {
        return;
    }

    if (app->stream) {
        pa_stream_disconnect(app->stream);
        pa_stream_unref(app->stream);
        app->stream = NULL;
    }

    snprintf(app->current_source, sizeof(app->current_source), "%s", mon_name);

    pa_sample_spec ss = {
        .format = PA_SAMPLE_FLOAT32LE,
        .rate = SAMPLE_RATE,
        .channels = 1,
    };
    app->stream = pa_stream_new(app->ctx, "QDeck Audio Sync", &ss, NULL);
    if (!app->stream) return;

    pa_stream_set_read_callback(app->stream, on_stream_read, app);
    pa_stream_set_state_callback(app->stream, on_stream_state, app);

    pa_buffer_attr attr = {
        .maxlength = (uint32_t)-1,
        .tlength = (uint32_t)-1,
        .prebuf = (uint32_t)-1,
        .minreq = (uint32_t)-1,
        .fragsize = HOP_SIZE * (uint32_t)sizeof(float),
    };
    pa_stream_connect_record(
        app->stream,
        mon_name,
        &attr,
        (pa_stream_flags_t)(PA_STREAM_ADJUST_LATENCY | PA_STREAM_DONT_INHIBIT_AUTO_SUSPEND)
    );
}

static void on_server_info(pa_context *c, const pa_server_info *i, void *userdata) {
    (void)c;
    App *app = (App *)userdata;
    if (i && i->default_sink_name) {
        connect_monitor_stream(app, i->default_sink_name);
    }
}

static void on_sub_event(pa_context *c, pa_subscription_event_type_t t, uint32_t idx, void *userdata) {
    (void)idx;
    if ((t & PA_SUBSCRIPTION_EVENT_FACILITY_MASK) == PA_SUBSCRIPTION_EVENT_SERVER) {
        pa_operation *op = pa_context_get_server_info(c, on_server_info, userdata);
        if (op) pa_operation_unref(op);
    }
}

static void on_ctx_state(pa_context *c, void *userdata) {
    App *app = (App *)userdata;
    switch (pa_context_get_state(c)) {
        case PA_CONTEXT_READY: {
            pa_context_set_subscribe_callback(c, on_sub_event, app);
            pa_operation *op1 = pa_context_subscribe(c, PA_SUBSCRIPTION_MASK_SERVER, NULL, NULL);
            if (op1) pa_operation_unref(op1);
            pa_operation *op2 = pa_context_get_server_info(c, on_server_info, app);
            if (op2) pa_operation_unref(op2);
            break;
        }
        case PA_CONTEXT_FAILED:
        case PA_CONTEXT_TERMINATED:
            if (app->mainloop) pa_mainloop_quit(app->mainloop, 1);
            break;
        default:
            break;
    }
}

int main(void) {
    signal(SIGPIPE, SIG_IGN);

    App app;
    memset(&app, 0, sizeof(app));
    app.rms_peak = 0.05f;
    app.bass_peak = 0.60f;
    app.beat_flux_mean = 0.60f;
    app.confirmed_bps = 1.15f; /* ~69 BPM calm start until steady pace is confirmed */
    app.last_onset_sec = now_monotonic();
    app.last_emit_sec = 0.0;

    for (int i = 0; i < FFT_SIZE; i++) {
        app.hann[i] = 0.5f * (1.0f - cosf((float)(6.28318530717958647692 * i) / (float)(FFT_SIZE - 1)));
    }
    app.fft_in = fftwf_alloc_real(FFT_SIZE);
    app.fft_out = fftwf_alloc_complex(BINS);
    app.plan = fftwf_plan_dft_r2c_1d(FFT_SIZE, app.fft_in, app.fft_out, FFTW_ESTIMATE);

    app.mainloop = pa_mainloop_new();
    app.api = pa_mainloop_get_api(app.mainloop);
    pa_signal_init(app.api);
    pa_signal_new(SIGINT, on_sig, &app);
    pa_signal_new(SIGTERM, on_sig, &app);

    app.ctx = pa_context_new(app.api, "QDeck Audio Sync");
    pa_context_set_state_callback(app.ctx, on_ctx_state, &app);
    pa_context_connect(app.ctx, NULL, PA_CONTEXT_NOFLAGS, NULL);

    int ret = 0;
    pa_mainloop_run(app.mainloop, &ret);

    if (app.stream) {
        pa_stream_disconnect(app.stream);
        pa_stream_unref(app.stream);
    }
    if (app.ctx) {
        pa_context_disconnect(app.ctx);
        pa_context_unref(app.ctx);
    }
    pa_signal_done();
    pa_mainloop_free(app.mainloop);

    fftwf_destroy_plan(app.plan);
    fftwf_free(app.fft_in);
    fftwf_free(app.fft_out);
    return ret;
}
