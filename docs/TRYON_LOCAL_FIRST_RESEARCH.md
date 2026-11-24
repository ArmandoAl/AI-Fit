# Probador de AI Fit con menor costo

Investigación del 2026-11-24. Propuesta para conversación y prototipo; los modelos citados no se han ejecutado sobre las fotos de la usuaria ni en su teléfono.

La mejor primera prueba para una sola usuaria es un probador por capas con una pose fija y fotografías de sus propias prendas puestas. Permite trasladar trabajo a una sesión inicial y reutilizar imágenes en el teléfono. En paralelo conviene evaluar un modelo especializado para los casos que necesiten una nueva fotografía. Un escaneo corporal ayuda a registrar proporciones y poses, pero no determina por sí solo la caída de cualquier prenda.

## Alcance

Reducir las llamadas de generación visual y el cómputo ocioso, conservando Supabase, DeepSeek y la selección actual de outfits. Diseño y funcionalidades adicionales quedan para después. El objetivo es una previsualización reconocible de ella con su ropa; una imagen convincente no acredita medidas ni ajuste físico exactos.

El video mencionado no está identificado. Los proyectos encontrados son referencias independientes; no se atribuye al influencer ninguna técnica concreta.

## Estado del código

Base revisada: `7bc559a`, después de consultar `origin`. Este análisis describe el repositorio, no la configuración desplegada ni la factura real.

| Parte | Evidencia local | Consecuencia |
| --- | --- | --- |
| Recorte de prendas | `apps/mobile/lib/core/services/apple_vision_background_removal_service.dart` y canal nativo iOS | Ya existe recorte local con Apple Vision en iOS 17+; no hay que empezar de cero |
| Selección de outfits | Scorer local en `packages/core` y orquestación DeepSeek | Puede conservarse independientemente del motor visual |
| Proveedor por defecto | `packages/core/lib/features/outfit/domain/outfit_models.dart` y `supabase/functions/_shared/image_providers.ts` | Cliente y router usan `seedream`; la selección por posición devuelve siempre ese proveedor |
| Gemini visual | `GoogleImageProvider` | Adaptador para `gemini-3.1-flash-image`, tamaño por defecto `2K`; sigue seleccionable explícitamente |
| Análisis visual | Acción `analyze_image` del router | Gemini también se usa para análisis; reducir generación y eliminar todo Gemini son alcances distintos |
| Imagen base antigua | Router devuelve HTTP 410 para `generate_base_image` | El servicio cliente antiguo conserva código, pero no es evidencia de una generación base pagada activa |
| Fotomontaje de prendas | `services/image-worker/flatlay_composer.py` | Compone un catálogo en fondo blanco; no viste un cuerpo |
| Servicio de imágenes | `services/image-worker/main.py` | Ejecuta CLIP, búsqueda y composición; no contiene un modelo local de virtual try-on |
| Infraestructura | `worker_warmup_service.dart` apunta a Cloud Run | Revisar configuración y facturación; el código no permite atribuirle los 300 MXN/mes |
| Web Jaspr | `docs/web_parity.md` | El probador aún no está portado; el primer experimento debe centrarse en iOS |

El README todavía describe Gemini como motor visual principal. Para elegir el proveedor efectivo, el código anterior es más preciso; falta contrastar versiones desplegadas, parámetros de solicitud y registros reales de uso. “CSP” podría referirse a CLIP u otro servicio: no se sustituye ese término por una suposición.

### Reutilización y cobros duplicados

`VirtualTryOnService` añade un timestamp a la clave de cada generación explícita. Esto permite regenerar un resultado malo, pero no reutiliza automáticamente el mismo look en llamadas nuevas. El cliente conserva la clave durante reintentos internos.

El router consulta un resultado previo y guarda el registro al terminar la generación. En ese trayecto no reserva primero un trabajo exclusivo. Existe por ello un riesgo de invocar dos veces al proveedor si dos peticiones de la misma clave se superponen; el `upsert` final no deshace un cobro externo. Es un riesgo identificado en código, no un doble cobro medido.

Propuesta: separar “abrir resultado existente” de “crear variante”, usar una huella de contenido para la caché y reservar el trabajo antes de llamar al proveedor. La huella debe incluir usuaria, versiones de fotos y prendas, pose, escena, modelo y versión del compositor. Las URLs firmadas expiran y no deben formar parte de esa huella. Guardar rutas de Storage y volver a firmarlas al leer.

## Alternativas investigadas

| Camino | Preparación | Dónde trabaja | Límite principal | Prioridad propuesta |
| --- | --- | --- | --- | --- |
| Fotos con cada prenda y composición por capas | Sesión con cámara fija, recortes y alineación | Teléfono | Pose fija; las interacciones entre prendas necesitan corrección | Primera prueba |
| Foto de producto deformada mediante malla o TPS | Puntos de hombros, cintura y contorno | Teléfono | Una deformación 2D no crea volumen ni tela oculta | Comparación de calidad |
| HR-VITON o DM-VTON | Pesos, segmentación y adaptación del pipeline | Primero equipo de desarrollo | Son modelos de IA; no son un SDK iPhone listo | Referencia de modelos ligeros |
| Mobile-VTON | Validar pesos, licencia y exportación | Objetivo móvil | La publicación no equivale a una integración Core ML disponible | Candidato condicionado |
| FASHN VTON 1.5 | Pesos y dependencias de pose/parser | Primero máquina con GPU compatible | Portabilidad y memoria; no resuelve todo el outfit de una vez | Referencia generativa |
| CatVTON | Modelo base, pesos y máscaras | Equipo con GPU | Memoria, licencia y disponibilidad del código | Candidato secundario |
| Avatar 3D y ropa digital | Cuerpo, rig, prendas y materiales | Preparación en equipo; render móvil posible | Digitalizar cada prenda y simularla añade mucho trabajo | Posponer |
| API bajo demanda | Integración y presupuesto | Nube por uso | Costo por resultado y dependencia externa | Recurso opcional |

### Fotos reales y composición por capas

Para este proyecto propongo fotografiarla con cada prenda en una misma posición, con encuadre, distancia e iluminación constantes. Recortar la prenda ya puesta conserva sus pliegues y volumen en esa pose. No basta con recortar toda la persona con Apple Vision: separar ropa, manos, cabello y piel puede requerir máscaras manuales o segmentación específica de ropa.

El compositor reutilizaría una foto de referencia y capas alineadas, con orden de profundidad y máscaras para brazos y cabello. Los puntos corporales permiten corregir desplazamientos pequeños. El render puede usar las capacidades gráficas del cliente sin una llamada de generación por combinación. La foto de referencia puede hacerse con ropa ajustada y cómoda; no hace falta una captura desnuda.

Es una hipótesis de implementación para validar. Cambiar de manga larga a tirantes descubre piel que otra foto no contiene; una chaqueta puede ocultar una blusa de forma distinta; una camiseta metida cambia la cintura del pantalón. Conviene fijar una pose con brazos ligeramente separados y aceptar corrección manual de las primeras prendas. Cambiar de pose requiere nuevas capas o un modelo que sintetice esas zonas.

El costo de preparación crece aproximadamente con prendas × poses, en lugar de fotografiar todas las combinaciones. Aun así, algunas combinaciones necesitan ajustes propios. No prometer cobertura completa del armario antes de probar vestidos, capas y siluetas diferentes.

Hay un antecedente de creadora: Sophia Liu explica que recreó el armario de Cher con fotografías con temporizador y Photoshop, animadas después en Figma. Era un prototipo visual, no un algoritmo automático de escaneo. Muestra por qué una demo convincente puede apoyarse en material preparado. [Relato original de Sophia Liu](https://www.studiosophy.com/blog/2022/2/28/i-recreated-chers-closet-from-clueless).

### Deformación geométrica y modelos ligeros

Una malla o transformación thin plate spline puede alinear una foto de prenda con hombros y cintura. Se puede ejecutar localmente, pero no recupera laterales, sombras ni caída real. La foto de la prenda puesta evita parte de ese trabajo, a cambio de una captura más exigente.

HR-VITON combina deformación, segmentación y síntesis, atendiendo oclusiones y desalineación. Su instalación publicada usa PyTorch/CUDA y licencia CC BY-NC 4.0. Es una referencia técnica para entender el problema, no una implementación móvil inmediata. [Repositorio oficial](https://github.com/sangyun884/HR-VITON).

DM-VTON publica un modelo ligero y reporta 40 FPS en una NVIDIA Tesla T4 y 37 MB de memoria. Esa medición no demuestra rendimiento en iPhone ni incluye necesariamente el costo de toda la preparación. El código requiere GPU con CuPy para partes de su flujo y tiene licencia CC BY-NC-SA 4.0. [Repositorio oficial](https://github.com/KiseKloset/DM-VTON) y [licencia](https://github.com/KiseKloset/DM-VTON/blob/main/LICENSE).

### Mobile-VTON

Los autores publican un modelo de 415 millones de parámetros y una demostración de inferencia offline en móvil. Es una pista especialmente relevante para la intención del proyecto. [Página de los autores](https://zhenchenwan.github.io/Mobile-VTON/) y [artículo](https://arxiv.org/abs/2603.00947).

La auditoría posterior del laboratorio encontró siete archivos de pesos públicos que suman aproximadamente 3.75 GB decimales para los componentes publicados. La cifra de parámetros del artículo no debe interpretarse como tamaño de descarga del pipeline completo. Los tamaños, revisiones y pruebas ejecutadas están en [los resultados del laboratorio](../labs/tryon/RESULTS.md).

La entrega pública consultada usa Python, Accelerate, datos preprocesados y scripts de evaluación con múltiples procesos. El README enlaza pesos, pero no ofrece instrucciones de integración iOS/Core ML. Antes de seleccionarlo hay que comprobar acceso a los pesos completos, licencia de cada componente, preprocesamiento local y conversión de operaciones. [README oficial](https://github.com/tmllab/2026_CVPR_Mobile-VTON) y [script de inferencia](https://github.com/tmllab/2026_CVPR_Mobile-VTON/blob/main/inference.sh).

### FASHN VTON 1.5 y CatVTON

FASHN publica código de inferencia y pesos de aproximadamente 2 GB, además de dependencias de pose y segmentación. Recibe una persona y una prenda, con categorías `tops`, `bottoms` y `one-pieces`. Código y modelo principal se presentan como Apache 2.0; revisar también las licencias del parser y demás componentes. [Repositorio](https://github.com/fashn-AI/fashn-vton-1.5) y [pesos oficiales](https://huggingface.co/fashn-ai/fashn-vton-1.5).

El pipeline selecciona CUDA o CPU automáticamente; esa elección no demuestra soporte eficiente en Apple Silicon ni una exportación a iPhone. Probarlo primero como referencia de calidad en hardware compatible. Vestir prendas sucesivas puede degradar la identidad o alterar prendas anteriores; calzado y accesorios requieren evaluación aparte. [Pipeline publicado](https://github.com/fashn-AI/fashn-vton-1.5/blob/main/src/fashn_vton/pipeline.py).

CatVTON documenta inferencia a 1024 × 768 con menos de 8 GB de VRAM y licencia CC BY-NC-SA 4.0. Es memoria de GPU, no una garantía de que funcione en un teléfono con esa RAM. Su ficha de pesos sigue accesible, pero el enlace GitHub consultado devolvió 404; hay que resolver el acceso al código antes de incorporarlo. [Ficha del autor](https://huggingface.co/zhengchong/CatVTON) y [artículo](https://arxiv.org/abs/2407.15886).

### Escaneo 3D y animación facial

Una reconstrucción corporal reproduce geometría y textura observadas. Para cambiar ropa en 3D todavía hace falta representar cada prenda, ajustarla al cuerpo, controlar colisiones y renderizar materiales. La fotogrametría también sufre con movimiento y objetos deformables, limitación que Apple describe para Object Capture. [Guía de captura de Apple](https://developer.apple.com/documentation/realitykit/capturing-photographs-for-realitykit-object-capture).

LivePortrait transfiere movimiento facial y de cabeza. Puede servir para animación posterior, pero no viste el cuerpo. Por ello no propongo capturar muchas expresiones ni añadir face swap a la primera prueba. [Proyecto oficial](https://github.com/KlingAIResearch/LivePortrait).

## Costos y alojamiento

La tarifa publicada para la salida de Gemini 3.1 Flash Image es de USD 0.067 a 1K, USD 0.101 a 2K y USD 0.151 a 4K, más entrada y otros conceptos aplicables. El adaptador actual usa 2K por defecto. [Tarifa oficial](https://aistudio.google.com/docs/pricing#gemini-3.1-flash-image).

Ejemplo calculado, no consumo observado: 10 imágenes nuevas al día durante 30 días suman 300 salidas; a 2K son USD 30.30 sólo de salida. Si se generan tres imágenes por cada una de esas diez sesiones, serían 900 salidas y USD 90.90. Abrir una imagen guardada no necesita regenerarla.

El código estima USD 0.027 para Seedream, pero ese número fijo no acredita la tarifa vigente ni el cobro real. Para comparar proveedores hay que dividir el gasto total entre resultados aceptados: una alternativa barata que exige varios intentos puede salir más cara.

Cloud Run puede escalar a cero; hay que revisar mínimos, modalidad de facturación, llamadas de warmup y costos separados de almacenamiento o registros. Eliminar el worker sin revisar sus usos rompería embeddings y composición. [Documentación de autoescalado](https://docs.cloud.google.com/run/docs/about-instance-autoscaling).

Si hace falta GPU ocasional, Runpod distingue trabajadores flexibles que escalan a cero de trabajadores activos. Se factura la vida del trabajador, incluyendo arranque e inactividad previa al apagado; almacenamiento y otros cargos deben presupuestarse aparte. Es una alternativa al servidor permanente, no una promesa de costo cero. [Facturación de Runpod](https://github.com/runpod/docs/blob/main/serverless/pricing.mdx).

Propuesta de control: tope mensual y por sesión en servidor, una generación opcional por acción explícita, reserva del presupuesto antes de invocar y ningún cambio automático a un proveedor de pago al fallar una opción local. Medir por separado generación, análisis, almacenamiento y worker.

## Prototipo propuesto

1. Confirmar modelo de iPhone, versión de iOS, chip y RAM de la Mac. Acordar cuánto tiempo de captura inicial resulta cómodo y si una pose fija satisface la previsualización.
2. Elegir una foto frontal y seis prendas representativas: dos superiores, dos inferiores, un vestido y una chaqueta. Incluir un estampado o texto y alguna silueta amplia para exponer fallos.
3. Preparar capas de las prendas puestas en esa pose, máscaras y puntos de registro. Compararlas con un montaje usando sólo sus fotos de producto. Trabajar con material autorizado y mantener las fotos personales fuera de Git.
4. Componer diez looks sin generación remota. Valorar rostro y proporciones, fidelidad de prendas, cruces de cintura, mangas, manos y cabello. El vestido y la chaqueta son pruebas de límites, no cobertura asumida.
5. Medir en el iPhone el tiempo de render, memoria máxima y comportamiento en uso continuado; medir también minutos de preparación por prenda. Objetivo inicial propuesto: al menos ocho de diez looks aceptables para ella sin retoque por combinación y respuesta cercana a un segundo con recursos ya cargados.
6. Si la calidad por capas es suficiente, integrar el render detrás de una interfaz de probador conservando el generador de outfits. Si falla en categorías importantes, evaluar FASHN como referencia y Mobile-VTON como candidato de ejecución local, según hardware, pesos y licencia.
7. Antes de cualquier uso remoto nuevo, implementar reutilización, reserva de trabajos y presupuesto. Comparar el costo por imagen aceptada con el flujo existente.

Los umbrales anteriores son criterios propuestos, no benchmarks alcanzados. El primer prototipo debe decidir si el esfuerzo inicial compensa la calidad obtenida; no hace falta comenzar con un escaneo profundo ni entrenar un modelo personal.

## Decisiones pendientes

La elección final depende del iPhone y de la Mac disponibles, la calidad aceptable de una vista fija y la disposición a fotografiar cada prenda puesta. También falta verificar el proveedor realmente desplegado y el origen de los cargos mensuales. Con la evidencia actual, recomiendo empezar por capas reales y mantener la generación especializada como opción para casos difíciles.
