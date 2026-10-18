# Primalis Online — revisión técnica inicial (2026-10-18)

## Alcance y estado de la revisión

Revisión estática del código en `main` (base observada: `6b608945a09151f9349f428fa09cf3c59b5dc99e`), configuraciones de exportación, pruebas automatizadas y logs disponibles de GitHub Actions. Los cambios correctivos de esta revisión están en una rama temporal; todavía requieren CI en esa rama y no deben considerarse verificados hasta que termine.

## Bloqueadores y hallazgos

### Bloqueador: el arranque de Godot falla en CI

Los runs conocidos `38414825257` (Web) y `38414826267` (Android), ambos del 13 de octubre de 2026, fallaron en el paso de arranque headless con:

```
ERROR: Parameter "material" is null.
at: material_get_instance_shader_parameters (servers/rendering/dummy/storage/material_storage.cpp:265)
```

Los pasos de prueba del mundo, exportación Web y empaquetado APK quedaron omitidos. La corrección anterior que evitaba consultas a slots vacíos no eliminó el error. La revisión también encontró una posible combinación peligrosa: la carga crea overrides por superficie sobre recursos GLB, mientras que el nodo puede tener un material global. Godot documenta un fallo de render similar al combinar esos dos niveles de override. Esta rama ahora duplica cada malla, migra materiales de superficie al recurso de malla, elimina los overrides de superficie y llena solo slots vacíos; la hipótesis debe confirmarse con la nueva ejecución CI.

### Población y navegación de fauna

`scripts/wild_dinosaur.gd` limitaba los destinos y el retorno de la fauna a ±970 m, aunque la isla jugable abarca aproximadamente ±2300 m. La rama alinea el límite de movimiento con el área jugable y agrega una prueba con un animal cerca del borde.

`scripts/main.gd` contaba para el mantenimiento poblacional solo animales a menos de 300 m, aunque conservaba nodos hasta 520 m. Eso podía provocar más apariciones de las previstas en la franja de 300–520 m; además, los cadáveres podían contar como animales vivos. La rama corrige el recuento para considerar vivos únicamente los animales vivos dentro del radio retenido.

### Trabajo innecesario por frame

El cálculo de proximidad al río/objeto cercano y la selección de región para la etiqueta de coordenadas se ejecutaban cada frame; la minimapa también se pedía redibujar cada frame. La rama reduce esas actualizaciones a un máximo aproximado de 10 Hz. Este cambio necesita confirmación de que el tacto/uso siguen respondiendo correctamente y de que no se introduce coste adicional apreciable.

### Cobertura de CI y publicación

El flujo Web original solo se ejecutaba ante cambios de `main` o ejecución manual. Esta rama habilita la compilación y pruebas Web en pull requests para detectar errores antes de publicar. El trabajo `deploy-pages` queda explícitamente limitado a `main` y nunca debe desplegar una rama de PR.

El APK Android es de prueba firmado en modo debug, no una compilación lista para Play Store. El flujo Android se habilita en PR con una clave debug temporal por ejecución; los PR no restauran ni guardan la clave persistente. Así se puede validar la exportación sin exponer material reutilizado de firma.

## Estado de producto confirmado

- Hay una partida local de un jugador, un T-Rex controlable, dinosaurios salvajes, hambre/sed/salud/resistencia, agua y plantas comestibles, combate básico, reaparición, minimapa, terreno, ríos y objetos ambientales.
- La isla usa terreno procedural de aproximadamente 4.6 × 4.6 km y carga decoración en chunks alrededor del jugador.
- Las superficies y modelos dependen de recursos GLB y texturas externas descargadas durante CI; sus formatos/licencias están registrados en `docs/ASSET_AUDIT.md`.
- No hay servidor de red implementado, autenticación, sincronización entre jugadores, matchmaking ni guardado persistente online. La interfaz sigue etiquetando la sesión como local.
- No hay prueba visual real de navegador, rendimiento/uso de memoria medido en un teléfono físico ni validación end-to-end de multijugador. La prueba headless no puede sustituirlas.

## Siguiente puerta de aceptación

1. Conseguir que la importación y el arranque headless pasen sin errores en la rama.
2. Pasar la prueba de activos, movimiento, supervivencia, combate y recuperación; exportar y validar el Web build en CI.
3. Comprobar en un navegador real que los recursos cargan, la consola queda limpia y los controles funcionan.
4. Ejecutar el flujo Android para validar el APK con versión y firma de prueba; instalarlo en un dispositivo físico y comprobar controles, gráficos, estabilidad, memoria y FPS.
5. Investigar el refresco/caché de archivos HTML, JavaScript, WASM y PCK en la URL existente antes de volver a publicar.
6. Mantener una sola web pública: https://misael546.github.io/PrimalisOnline/. No desplegar hasta que las puertas anteriores estén verdes. El servidor casero autoritativo y SQLite vienen después, con WSS compatible con navegador y pruebas cliente-servidor reales.
