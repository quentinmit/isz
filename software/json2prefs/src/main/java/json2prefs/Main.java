package json2prefs;

import java.io.InputStreamReader;
import java.util.prefs.Preferences;

import javax.json.*;

public class Main {
    static void setPrefs(Preferences parent, JsonObject data) {
        for (var entry : data.entrySet()) {
            JsonValue value = entry.getValue();
            if (value instanceof JsonObject o) {
                setPrefs(parent.node(entry.getKey()), o);
            } else if (value instanceof JsonString s) {
                parent.put(entry.getKey(), s.getString());
            } else {
                parent.put(entry.getKey(), value.toString());
            }
        }
        // No need to flush; guaranteed to flush on exit.
    }
    public static void main(String[] args) {
        JsonReader jsonReader = Json.createReader(new InputStreamReader(System.in));
        JsonObject data = jsonReader.readObject();
        setPrefs(Preferences.userRoot(), data);
    }
}
