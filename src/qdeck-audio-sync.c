/*
 * QDeck: Lightweight real-time PipeWire audio analyzer for QuickShell waves & vibing kitty.
 * Connects to active default sink monitor via libpulse async API + FFTW3f spectral flux/beat tracking.
 * Outputs smoothed control frames (~60 Hz when audio active): "<level> <bass> <beat> <speed>\n"
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
#define BINS (FFT_SIZE / 2 + 1)

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

    float rms_peak;
    float bass_peak;
    float beat_flux_mean;
    float total_flux_mean;
    float flux_density;

    float level_env;
    float bass_env;
    float beat_env;
    float speed_env;
    float onset_rate_hz;

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

    /* Silence gate: smoothly settle to zero and stop spamming stdout while silent */
    if (rms < 2.5e-5f) {
        app->silent_frames++;
        app->level_env *= 0.70f;
        app->bass_env *= 0.67f;
        app->beat_env *= 0.61f;
        app->speed_env += (0.45f - app->speed_env) * 0.12f;
        app->flux_density *= 0.81f;

        if (app->silent_frames < 30 || !app->settled_emitted) {
            if ((t - app->last_emit_sec) >= 0.020) {
                app->last_emit_sec = t;
                if (app->level_env < 0.004f && app->bass_env < 0.004f && app->beat_env < 0.004f) {
                    printf("0.000 0.000 0.000 0.450\n");
                    app->settled_emitted = 1;
                } else {
                    printf("%.3f %.3f %.3f %.3f\n", app->level_env, app->bass_env, app->beat_env, app->speed_env);
                }
                fflush(stdout);
            }
        }
        return;
    }

    app->silent_frames = 0;
    app->settled_emitted = 0;

    /* Extract sub-bass/kick (bins 1..4: ~47-188Hz), beat body flux (bins 1..18: ~47-844Hz),
       and broadband spectral activity (bins 1..96: ~47-4500Hz) */
    float bass_energy = 0.0f;
    float beat_flux = 0.0f;
    float total_flux = 0.0f;
    for (int k = 1; k < 96 && k < BINS; k++) {
        float re = app->fft_out[k][0];
        float im = app->fft_out[k][1];
        float mag = sqrtf(re * re + im * im);
        float logm = log1pf(mag * 1.5f);

        if (k <= 4) {
            bass_energy += mag;
        }

        float diff = logm - app->prev_log_mag[k];
        if (diff > 0.0f) {
            if (k <= 18) {
                float w_beat = (k <= 5) ? 2.0f : 1.0f;
                beat_flux += w_beat * diff;
            }
            float w_tot = (k <= 5) ? 1.5f : ((k <= 24) ? 1.0f : 0.7f);
            total_flux += w_tot * diff;
        }
        app->prev_log_mag[k] = logm;
    }
    bass_energy /= 4.0f;

    /* Adaptive rolling peak envelope so quiet & loud tracks both feel expressive */
    app->rms_peak = fmaxf(rms, fmaxf(0.012f, app->rms_peak * 0.993f));
    app->bass_peak = fmaxf(bass_energy, fmaxf(0.45f, app->bass_peak * 0.992f));

    float norm_level = clampf(powf(rms / app->rms_peak, 0.72f), 0.0f, 1.0f);
    float norm_bass = clampf(powf(bass_energy / app->bass_peak, 0.78f), 0.0f, 1.0f);

    /* Fast attack, smooth liquid release */
    if (norm_level > app->level_env)
        app->level_env += (norm_level - app->level_env) * 0.62f;
    else
        app->level_env += (norm_level - app->level_env) * 0.22f;

    if (norm_bass > app->bass_env)
        app->bass_env += (norm_bass - app->bass_env) * 0.70f;
    else
        app->bass_env += (norm_bass - app->bass_env) * 0.26f;

    /* Rolling mean fluxes & rhythmic beat onset detection (~40-260 BPM range) */
    app->beat_flux_mean = app->beat_flux_mean * 0.91f + beat_flux * 0.09f;
    app->total_flux_mean = app->total_flux_mean * 0.92f + total_flux * 0.08f;

    float act = clampf(app->total_flux_mean * 0.048f, 0.0f, 1.0f);
    app->flux_density = app->flux_density * 0.88f + act * 0.12f;

    app->beat_env *= 0.69f;
    if (beat_flux > fmaxf(app->beat_flux_mean * 1.65f + 0.15f, 0.95f) && (t - app->last_onset_sec) >= 0.23) {
        double ioi = t - app->last_onset_sec;
        app->last_onset_sec = t;
        app->beat_env = fminf(1.0f, app->beat_env + 0.88f);

        if (ioi >= 0.23 && ioi <= 1.50) {
            float inst_hz = (float)(1.0 / ioi);
            app->onset_rate_hz = app->onset_rate_hz * 0.72f + clampf(inst_hz, 0.65f, 3.25f) * 0.28f;
        }
    } else if ((t - app->last_onset_sec) > 1.35) {
        /* Smoothly relax cadence during sustained ambient pads or breakdowns */
        app->onset_rate_hz += (0.80f - app->onset_rate_hz) * 0.05f;
    }

    /* Map musical beat cadence + broadband density + loudness cleanly to speed [0.40 .. 2.40] */
    float target_speed = 0.18f + (app->onset_rate_hz * 0.56f) + (app->flux_density * 0.38f) + (app->level_env * 0.12f);
    target_speed = clampf(target_speed, 0.40f, 2.40f);
    if (target_speed > app->speed_env)
        app->speed_env += (target_speed - app->speed_env) * 0.16f;
    else
        app->speed_env += (target_speed - app->speed_env) * 0.11f;

    if ((t - app->last_emit_sec) >= 0.020) {
        app->last_emit_sec = t;
        if (printf("%.3f %.3f %.3f %.3f\n", app->level_env, app->bass_env, app->beat_env, app->speed_env) < 0 || fflush(stdout) != 0) {
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
    pa_stream_state_t st = pa_stream_get_state(s);
    if (st == PA_STREAM_FAILED) {
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
    app.total_flux_mean = 1.50f;
    app.speed_env = 0.78f;
    app.onset_rate_hz = 1.1f;
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
