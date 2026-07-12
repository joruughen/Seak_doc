shader_type spatial;
render_mode blend_mix, depth_draw_never;

// Valores base
uniform vec3 albedo : source_color = vec3(0.0, 0.32, 0.43);
uniform vec3 albedo2 : source_color = vec3(0.0, 0.47, 0.76);
uniform float metallic : hint_range(0.0, 1.0) = 0.0;
uniform float roughness : hint_range(0.0, 1.0) = 0.02;
uniform sampler2D wave;
uniform sampler2D texture_normal;
uniform sampler2D texture_normal2;

// --- OLAS (vertex) ---
// IMPORTANTE: wave_height() tiene un gemelo exacto en Water.gd (_wave_height).
// Cualquier cambio aquí debe replicarse allá o la boyancia se desincroniza.
uniform float wave_time = 0.0;                    // reloj compartido, lo setea Water.gd cada frame
uniform float wave_speed = 0.03;                  // UV por segundo
uniform vec2 wave_direction = vec2(1.0, 0.35);    // dirección octava 1
uniform vec2 wave_direction2 = vec2(-0.55, 1.0);  // dirección octava 2 (cruzada)
uniform float noise_scale = 10.0;                 // escala XZ octava 1
uniform float noise_scale2 = 5.3;                 // escala XZ octava 2 (no múltiplo entero, evita patrones)
uniform float wave_blend : hint_range(0.0, 1.0) = 0.35;   // peso de la octava 2
uniform float wave_sharpness : hint_range(0.5, 4.0) = 1.6; // >1 afila crestas, aplana valles
uniform float height_scale = 0.25;

// Detalle de normal maps (solo visual, no afecta la física)
uniform float time_scale : hint_range(0.0, 0.2, 0.005) = 0.025;

// Colores de profundidad
uniform vec4 color_deep : source_color = vec4(0.1, 0.2, 0.4, 0.9);
uniform vec4 color_shallow : source_color = vec4(0.3, 0.6, 0.8, 0.2);
uniform float beers_law = 2.0;
uniform float depth_offset = -0.75; // conservado por compatibilidad

uniform float edge_scale = 0.25;
uniform float near = 1.0;
uniform float far = 100.0;
uniform vec3 edge_color : source_color = vec3(1.0, 1.0, 1.0);

// --- GODOT 4 DEPTH TEXTURE ---
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;

varying float height;
varying vec3 world_pos;

float fresnel(float amount, vec3 normal, vec3 view) {
    return pow((1.0 - clamp(dot(normalize(normal), normalize(view)), 0.0, 1.0 )), amount);
}

// Altura de ola en [0,1]: dos octavas de ruido scrolleadas en direcciones
// cruzadas que interfieren, con crestas afiladas por pow().
float wave_height(vec2 pos) {
    float t = wave_time * wave_speed;
    vec2 uv1 = pos / noise_scale + t * wave_direction;
    vec2 uv2 = pos / noise_scale2 - t * 1.31 * wave_direction2;
    float h1 = texture(wave, uv1).r;
    float h2 = texture(wave, uv2).r;
    return pow(mix(h1, h2, wave_blend), wave_sharpness);
}

void vertex() {
    world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    height = wave_height(world_pos.xz);
    VERTEX.y += height * height_scale;

    // Normal por diferencias finitas para que la luz siga la forma de la ola.
    // Asume que el plano de agua no está rotado (espacio objeto ≈ mundo).
    float e = 0.5;
    float hx = wave_height(world_pos.xz + vec2(e, 0.0));
    float hz = wave_height(world_pos.xz + vec2(0.0, e));
    NORMAL = normalize(vec3((height - hx) * height_scale / e, 1.0, (height - hz) * height_scale / e));
}

void fragment() {
    // 1. Matemáticas de Profundidad Lineal
    float raw_depth = texture(depth_tex, SCREEN_UV).r;

    // --- EL FIX PARA EL RENDERIZADOR "COMPATIBILITY" (OPENGL) ---
    // En OpenGL, la profundidad se lee en un espacio de -1.0 a 1.0.
    float depth_z = raw_depth * 2.0 - 1.0;

    vec4 view_pos = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, depth_z, 1.0);
    view_pos /= view_pos.w;
    float linear_depth = -view_pos.z;

    float linear_pos = -VERTEX.z;
    float depth_diff = linear_depth - linear_pos;

    // Seguro anti-vacío del editor
    if (raw_depth < 0.0001 || raw_depth > 0.9999) {
        depth_diff = 1000.0;
    } else {
        depth_diff = max(0.0, depth_diff);
    }

    // 2. Transparencia y Absorción (Beer's Law)
    float depth_blend = exp(-depth_diff * beers_law);

    vec3 depth_color = mix(color_deep.rgb, color_shallow.rgb, depth_blend);
    float depth_alpha = mix(color_deep.a, color_shallow.a, depth_blend);

    // 3. Espuma Suavizada (Edge) + espuma en crestas altas
    float foam_effect = 1.0 - smoothstep(0.0, edge_scale, depth_diff);
    float crest_foam = smoothstep(0.82, 1.0, height) * 0.35;
    foam_effect = clamp(foam_effect + crest_foam, 0.0, 1.0);

    vec3 water_color = mix(depth_color, edge_color, foam_effect);
    float final_alpha = max(depth_alpha, foam_effect);

    // 4. Animación de Normales (detalle fino, sigue las direcciones de las olas)
    vec2 time = (TIME * wave_direction) * time_scale;
    vec2 time2 = (TIME * wave_direction2) * time_scale;
    vec3 normal_blend = mix(texture(texture_normal, world_pos.xz / noise_scale + time).rgb, texture(texture_normal2, world_pos.xz / noise_scale2 + time2).rgb, 0.5);

    // 5. Fresnel (Reflejos del Cielo vs Interior del agua)
    float fresnel_val = fresnel(5.0, NORMAL, VIEW);
    vec3 surface_color = mix(albedo, albedo2, fresnel_val);

    ALBEDO = mix(water_color, surface_color, fresnel_val);
    ALPHA = clamp(final_alpha, 0.0, 1.0);
    METALLIC = metallic;
    ROUGHNESS = roughness;
    NORMAL_MAP = normal_blend;
}
