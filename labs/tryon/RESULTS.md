# Resultados iniciales del laboratorio

Medidos el 2026-11-24 en `hpmeserver`, Ryzen 5 5500U y 14.45 GiB de RAM. La MacBook Air M4 y el iPhone 17 todavía no se han utilizado para medir este laboratorio.

## Composición local

El compositor pasó siete pruebas: transparencia, máscara de oclusión, alineación con rotación y escala, rechazo de puntos degenerados, invalidación por cambio de recurso, reconstrucción de una salida corrupta y límites de rutas/tamaño.

Con tres capas sintéticas a 768 × 1024 y veinte repeticiones, Pillow 12.0.0 tardó una mediana de **66.53 ms** y un máximo de **75.44 ms** en renderizar. El proceso completo —lectura, veinte renders y guardado— tardó **1,385.54 ms**. Una lectura posterior con caché válida tardó **37.91 ms**. La caché todavía lee los recursos para calcular su huella.

Son tiempos de composición de figuras preparadas. No incluyen segmentación de ropa, captura, creación de máscaras, inferencia ni transmisión. No acreditan fidelidad sobre fotos reales ni rendimiento en iPhone.

Artefactos locales ignorados por Git: `output/layers.png`, su reporte `output/layers.json` y `private/synthetic/manifest.json`.

## Prueba 3D

Blender **4.5.9 LTS**, portable verificado con el manifiesto SHA-256 oficial, exportó una escena con **15 mallas separadas**, **1,924 triángulos** y un GLB de **73,812 bytes**. El script completó exportación, guardado y render en **2.39 segundos**, usando CPU, dos hilos y ocho muestras a 384 × 512. El tiempo no incluye descarga ni arranque del proceso Blender.

Se inspeccionó el render. Es un maniquí geométrico de prueba con prendas sintéticas; conserva intersecciones y formas simplificadas. No es una reconstrucción, un avatar personalizado, una simulación de tela ni una malla con rig. Prueba que el servidor puede preparar y exportar recursos 3D pequeños sin CUDA.

Artefactos locales ignorados: `output/3d/synthetic_outfit.blend`, `.glb`, `.png` y `report.json`. La exportación GLB todavía debe probarse en el visor o motor que se elija para iOS.

## Auditoría de modelos

Se consultaron metadatos y código públicos sin descargar pesos ni ejecutar inferencia.

| Modelo | Revisión de pesos | Revisión de código | Tamaño identificado |
| --- | --- | --- | --- |
| Mobile-VTON | `0063147c171518b391fff5e44d04555c12370c35` | `57410f20ac0e1703af795702e10473565feaa711` | 3,752,217,232 bytes en siete archivos |
| FASHN VTON 1.5 | `7720683168567eb5a2a4c67f15116c6e29c83ded` | `7c0f10af3f91ad4048fe9729c470a13ef905d25a` | 1,943,668,048 bytes en el modelo principal |

El código consultado no contiene archivos Apple identificados por la auditoría. En Mobile-VTON falta el `environment.yaml` referenciado por su README. Eso justifica una evaluación de portabilidad antes de instalar el stack completo; no demuestra imposibilidad de conversión.

## Próximo experimento

Seleccionar fotos y conocer la RAM de la Mac. Preparar un montaje real con dos prendas y un avatar estático ajustado mediante referencias. Después evaluar qué aporta un modelo preentrenado frente a esos recursos, y medir cualquier candidato móvil en el iPhone real. El servidor queda preparado para las tareas ligeras; entrenamiento y reconstrucciones CUDA intensivas no forman parte de esta primera prueba.
