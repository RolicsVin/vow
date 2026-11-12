package io.github.pythonbridge;

import android.app.Activity;
import android.content.Context;
import android.util.Log;

import com.chaquo.python.PyObject;
import com.chaquo.python.Python;
import com.chaquo.python.android.AndroidPlatform;

import org.godotengine.godot.Godot;
import org.godotengine.godot.plugin.GodotPlugin;
import org.godotengine.godot.plugin.UsedByGodot;
import org.json.JSONObject;

import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.ConcurrentLinkedQueue;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.function.Consumer;

/**
 * Godot Android plugin that runs Python in-process through Chaquopy.
 *
 * GDScript side (backends/backend_android.gd):
 *   start(workerDir, "dir1\ndir2")  -> boolean   (Python starts asynchronously)
 *   send(requestJson)
 *   poll()                          -> String    (JSON lines separated by '\n', may be empty)
 *   shutdown()
 *
 * All Python work happens on one background thread, so requests run in order and
 * the Godot thread is never blocked.
 */
public class PythonBridgePlugin extends GodotPlugin {
    private static final String TAG = "PythonBridge";

    /** Public (non-synthetic) class so Chaquopy can call accept() from Python. */
    public static class Sink implements Consumer<String> {
        private final ConcurrentLinkedQueue<String> queue;

        Sink(ConcurrentLinkedQueue<String> queue) {
            this.queue = queue;
        }

        @Override
        public void accept(String line) {
            queue.add(line);
        }
    }

    private final ConcurrentLinkedQueue<String> outbox = new ConcurrentLinkedQueue<>();
    private ExecutorService executor = Executors.newSingleThreadExecutor();
    private volatile PyObject bridge;

    public PythonBridgePlugin(Godot godot) {
        super(godot);
    }

    @Override
    public String getPluginName() {
        return "PythonBridgeAndroid";
    }

    @UsedByGodot
    public boolean start(final String workerDir, final String extraPaths) {
        Activity activity = getActivity();
        if (activity == null) {
            return false;
        }
        final Context context = activity.getApplicationContext();
        if (executor.isShutdown()) {
            executor = Executors.newSingleThreadExecutor();
        }
        executor.execute(() -> {
            try {
                if (!Python.isStarted()) {
                    Python.start(new AndroidPlatform(context));
                }
                Python py = Python.getInstance();
                py.getModule("site").callAttr("addsitedir", workerDir);
                List<String> paths = new ArrayList<>();
                for (String p : extraPaths.split("\n")) {
                    if (!p.isEmpty()) {
                        paths.add(p);
                    }
                }
                bridge = py.getModule("bridge_worker").callAttr(
                        "create_embedded", new Sink(outbox), paths.toArray(new String[0]));
            } catch (Throwable t) {
                Log.e(TAG, "Python start failed", t);
                pushFatal("Python start failed: " + t);
            }
        });
        return true;
    }

    @UsedByGodot
    public void send(final String requestJson) {
        executor.execute(() -> {
            PyObject b = bridge;
            if (b == null) {
                pushResponseError(requestJson, "Python bridge is not initialised");
                return;
            }
            try {
                b.callAttr("handle_line", requestJson);
            } catch (Throwable t) {
                Log.e(TAG, "handle_line failed", t);
                pushResponseError(requestJson, "Internal error: " + t);
            }
        });
    }

    @UsedByGodot
    public String poll() {
        StringBuilder sb = new StringBuilder();
        String line;
        while ((line = outbox.poll()) != null) {
            if (sb.length() > 0) {
                sb.append('\n');
            }
            sb.append(line);
        }
        return sb.toString();
    }

    @UsedByGodot
    public void shutdown() {
        executor.execute(() -> {
            PyObject b = bridge;
            bridge = null;
            if (b != null) {
                try {
                    b.callAttr("close");
                } catch (Throwable t) {
                    Log.w(TAG, "close failed", t);
                }
            }
        });
    }

    @Override
    public void onMainDestroy() {
        super.onMainDestroy();
        executor.shutdown();
    }

    private void pushFatal(String message) {
        try {
            JSONObject o = new JSONObject();
            o.put("type", "fatal");
            o.put("error", message);
            outbox.add(o.toString());
        } catch (Exception ignored) {
        }
    }

    private void pushResponseError(String requestJson, String message) {
        try {
            int id = new JSONObject(requestJson).optInt("id", -1);
            JSONObject o = new JSONObject();
            o.put("type", "response");
            o.put("id", id);
            o.put("ok", false);
            o.put("error", message);
            o.put("traceback", "");
            outbox.add(o.toString());
        } catch (Exception ignored) {
        }
    }
}
