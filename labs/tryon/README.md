# Laboratorio local del probador

Pruebas aisladas para preparar recursos que AI Fit pueda reutilizar en el iPhone 17. El laboratorio contiene un compositor 2D funcional, una escena 3D sintética exportable y una auditoría de modelos preentrenados. Todavía no reconstruye a la usuaria, simula telas ni ejecuta un modelo de probador en iOS.

## Equipo disponible y reparto del trabajo

| Equipo | Trabajo previsto | Límite relevante |
| --- | --- | --- |
| Servidor Ryzen 5 5500U, Radeon integrada, 14.45 GiB RAM | Composición, preparación ligera, pruebas y exportación 3D pequeña | Sin NVIDIA/CUDA; unos 20 GiB libres al iniciar el laboratorio |
| MacBook Air M4 | Ajuste del avatar, texturas, preparación de prendas y pruebas de conversión | RAM pendiente; comprobar antes de cargar pesos grandes |
| iPhone 17 | Visualización y, si la conversión lo permite, inferencia | Medir memoria, latencia y temperatura en el dispositivo real |

No hace falta entrenar para empezar: inferencia usa pesos ya entrenados; modelado prepara geometría; ajuste adapta un recurso existente; entrenamiento modifica pesos con ejemplos. Son trabajos distintos. Un maniquí puede posicionar una prenda con transformaciones o un esqueleto, sin entrenar una red para cada colocación.

## Entorno y comandos

Desde la raíz del repositorio, Python 3.11 o posterior:

```bash
python3 -m venv labs/tryon/.venv
labs/tryon/.venv/bin/python -m pip install --only-binary=:all: -r labs/tryon/requirements.txt
python3 labs/tryon/preflight.py
labs/tryon/.venv/bin/python -m unittest discover -s labs/tryon -p 'test_*.py' -v
labs/tryon/.venv/bin/python labs/tryon/make_demo.py
labs/tryon/.venv/bin/python labs/tryon/compose.py labs/tryon/private/synthetic/manifest.json labs/tryon/output/layers.png --repeat 20
python3 labs/tryon/model_audit.py
```

Pillow está fijado a 12.0.0 en un entorno virtual propio. `model_audit.py` sólo descarga metadatos y archivos de código de repositorios públicos; no carga pesos, imágenes personales ni claves. Registra las revisiones consultadas para distinguir resultados de futuras versiones.

### Blender en este servidor

Se instaló Blender 4.5.9 LTS portable bajo `.cache`, comprobando SHA-256 con el manifiesto oficial. No necesita sudo ni modifica el Blender de otros proyectos. El instalador siguiente es para Linux x64; en la Mac usar Blender para Apple Silicon.

```bash
nice -n 15 python3 labs/tryon/bootstrap_blender.py
nice -n 15 labs/tryon/.cache/blender-4.5.9-linux-x64/blender --background --factory-startup --threads 2 --python labs/tryon/blender_fixture.py -- --output labs/tryon/output/3d
python3 labs/tryon/inspect_glb.py labs/tryon/output/3d/synthetic_outfit.glb
```

La prueba genera `.blend`, `.glb`, PNG y un reporte. El avatar y las prendas son mallas separadas, estáticas y sintéticas. La prueba no implementa rig, transferencia automática de ropa, escaneo ni predicción de ajuste. `--body-json` admite parámetros aproximados `height_m`, `shoulder_width_m`, `waist_width_m` y `hip_width_m`; las anchuras se definen para una altura de referencia de 1.70 m y toda la figura se escala después. Este maniquí sirve para probar el transporte de recursos, no para estimar medidas de una persona.

## Fotos y recursos privados

```text
private/
  subject/
    references/       fotos de referencia elegidas
    capture/          sesión nueva, si las referencias no bastan
  garments/
    top_001/          fotos, recorte y máscara de una prenda
    bottom_001/
  prepared/           imágenes con orientación normalizada, máscaras y manifest.json
output/               resultados, métricas y bundle para la Mac
.cache/               Blender y futuros pesos
```

Esas carpetas y `.venv` están excluidas de Git. Las fotos reales no se han buscado en otras carpetas del servidor: hace falta indicar la ruta seleccionada. Los archivos originales se conservan; preparar copias para recorte y alineación. `chmod 700 private` restringe el acceso del directorio en sistemas Unix, pero no cifra los archivos.

Para empezar, elegir cuatro fotos de cuerpo entero de la misma época —frente, espalda y ambos perfiles—, una o dos del rostro y la altura real si se busca escala aproximada. Ropa ajustada y cómoda ayuda a ver el contorno; no hacen falta fotos desnuda ni una colección de expresiones. Las vistas que falten no se recuperan con exactitud a partir de una foto frontal.

Preparar también una prenda superior y una inferior, con fotos de frente y espalda y una foto de cada una puesta. Para composición por capas, las fotos puestas deben compartir cámara, encuadre, luz y pose; conviene separar ligeramente los brazos del torso. Fotos casuales existentes sirven de referencia, pero probablemente no estén alineadas para recombinar prendas.

La primera versión 3D debe adaptar una malla sencilla usando referencias y texturas. Para una reconstrucción por fotogrametría posterior, planear una sesión aparte con muchas vistas solapadas y postura inmóvil; un álbum de fotos con ropa y poses diferentes no equivale a un escaneo.

## Formato del compositor

El manifiesto se guarda junto a sus recursos y define `canvas: [ancho, alto]` y `layers` ordenadas del fondo al frente. Cada capa contiene `image`, y opcionalmente `mask`, `source_anchors` y `target_anchors`. Los puntos están expresados en píxeles: dos puntos en la imagen original y sus dos destinos en el lienzo. Sin puntos, la imagen debe tener el mismo tamaño que el lienzo.

Las máscaras son imágenes en escala de grises del mismo tamaño que su capa: blanco conserva, negro oculta. Se multiplican por el alfa existente. Brazos, manos o cabello que deban quedar delante se añaden como capas finales. El compositor no produce automáticamente esas máscaras y no inventa partes ocultas.

El compositor acepta recursos relativos dentro de la carpeta del manifiesto, hasta 4096 píxeles por lado y 32 capas. La orientación EXIF debe normalizarse antes de asignar puntos. La huella incluye manifiesto, bytes de los recursos y versión del motor. Una imagen alterada o corrupta invalida la caché. Es una caché local experimental, no corrige todavía la idempotencia del router en producción.

## Modelos y ruta 3D

La auditoría del 2026-11-24 encontró:

| Proyecto | Descarga de pesos identificada | Licencia indicada | Siguiente comprobación |
| --- | --- | --- | --- |
| Mobile-VTON | 3,752,217,232 bytes, aproximadamente 3.75 GB decimales en siete archivos | CC BY-NC-SA 4.0 | Dependencias, memoria real y exportación de cada módulo a Core ML |
| FASHN VTON 1.5 | 1,943,668,048 bytes, aproximadamente 1.94 GB decimales para el modelo principal | Apache 2.0 | Pose/parser adicionales y compatibilidad del pipeline con MPS |

Son tamaños de archivos, no memoria de inferencia ni tamaño final optimizado. El árbol de código de Mobile-VTON no contiene el `environment.yaml` que solicita su README ni archivos de despliegue Apple identificados por la auditoría. Es una tarea de portabilidad pendiente; descargar todos los pesos no demuestra que el pipeline pueda correr en iOS. [Pesos de Mobile-VTON](https://huggingface.co/FlashStight/Mobile-VTON) y [código](https://github.com/tmllab/2026_CVPR_Mobile-VTON).

Los pesos descargables de FASHN son distintos de su API comercial. El primer conjunto permite experimentar sin pagar por solicitud; requiere cómputo propio y revisar las dependencias. El pipeline publicado selecciona CUDA o CPU automáticamente. No interpretar esa selección como soporte MPS comprobado. [Pesos](https://huggingface.co/fashn-ai/fashn-vton-1.5) y [pipeline](https://github.com/fashn-AI/fashn-vton-1.5/blob/main/src/fashn_vton/pipeline.py).

Para reconstrucción 3D se investigó ReMu, de ETH, que separa prendas y cuerpo. Su entorno probado usa una A100 con CUDA 12.1 y necesita recursos externos, incluidos modelos corporales licenciados. Es una referencia útil, pero no se instala como si fuera compatible con esta Radeon o con Metal. [Repositorio de ReMu](https://github.com/eth-ait/ReMu).

Dress-1-to-3 investiga reconstruir prendas separadas y listas para simulación a partir de imágenes usando patrones, difusión y física. La página consultada publica el trabajo y demostraciones; no ofrece allí un botón de código con una integración lista para instalar. Sirve para orientar el método, no para prometer una solución móvil existente. [Página de los autores](https://dress-1-to-3.github.io/).

## Resultados iniciales

Ver [RESULTS.md](RESULTS.md) para mediciones del servidor y límites. El siguiente paso de personalización requiere la carpeta de fotos elegida. La ruta de trabajo en la Mac y el prompt están en [MAC_HANDOFF.md](MAC_HANDOFF.md).
