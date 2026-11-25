# Continuar el laboratorio en la MacBook Air M4

Este prompt continúa el trabajo desde la rama `feature/tryon-local-lab`, publicada en el repositorio remoto. Clonar esa rama para obtener el laboratorio y la investigación previa:

```bash
git clone --branch feature/tryon-local-lab https://github.com/ArmandoAl/AI-Fit.git ~/AI-Fit-tryon-lab
```

Si ya existe un checkout, comprobar que no tenga cambios pendientes antes de ejecutar:

```bash
git fetch origin
git switch feature/tryon-local-lab
git pull --ff-only
```

Como alternativa offline, el bundle local `labs/tryon/output/aifit-tryon-lab.bundle` contiene el estado inicial del laboratorio en `59dd4ac`, excluyendo fotos, pesos y entornos ignorados. La rama remota puede incluir actualizaciones posteriores.

Desde la Mac conectada al servidor por SSH, copiar el bundle con el host que ya se use para `hpmeserver`. Por ejemplo, si el alias SSH `hpmeserver` está configurado:

```bash
scp armando@hpmeserver:/home/armando/projects/AI-Fit/labs/tryon/output/aifit-tryon-lab.bundle ~/Downloads/aifit-tryon-lab.bundle
git clone -b feature/tryon-local-lab ~/Downloads/aifit-tryon-lab.bundle ~/AI-Fit-tryon-lab
```

Si no existe ese alias, sustituirlo por la dirección del servidor con la que ya funcione SSH. La copia nueva tiene el bundle como origen; para este laboratorio no necesita modificar el remoto de otro checkout.

Colocar las fotos elegidas en `~/AI-Fit-tryon-lab/labs/tryon/private/subject/references` y las fotos de una o dos prendas en `private/garments`. Se pueden copiar directamente desde el iPhone a esas carpetas. No incluirlas en commits. El prompt permite empezar sin fotos con las pruebas sintéticas y continuar al disponer de ellas.

## Prompt para el agente de la Mac

```text
Continúa el laboratorio de AI Fit en este checkout de la MacBook Air M4.
Lee AGENTS.md, labs/tryon/README.md, labs/tryon/RESULTS.md y
docs/TRYON_LOCAL_FIRST_RESEARCH.md antes de modificar el proyecto.

Objetivo: preparar un avatar y prendas reutilizables para el iPhone 17 y
evaluar un modelo de probador preentrenado local. Priorizar preparación
inicial y ejecución local. No entrenar desde cero ni contratar servicios.

1. Comprueba Git y crea feature/tryon-mac-evaluation desde la rama del
   laboratorio sin descartar cambios. Ejecuta preflight.py para conocer
   RAM y disco; no asumas que el chip M4 garantiza memoria suficiente.

2. Puedes instalar herramientas gratuitas necesarias dentro del entorno
   del laboratorio. Usa Python 3.11 o 3.12 para las dependencias de modelos,
   entorno virtual propio y Blender para Apple Silicon. Conserva los otros
   entornos y ajustes del equipo. Antes de descargar pesos, comprueba tamaños
   y espacio libre y reserva margen para al menos dos veces su descarga.

3. Reproduce primero los siete tests del compositor y la escena sintética
   de Blender. El script blender_fixture.py admite ejecución con el binario
   de /Applications/Blender.app/Contents/MacOS/Blender; el instalador Linux
   bootstrap_blender.py no se ejecuta aquí. Limita CPU a dos hilos para esta
   prueba y registra tiempo, memoria y artefactos exportados.

4. Busca fotos sólo en labs/tryon/private/subject/references y prendas sólo
   en private/garments. Si están vacías, continúa con el laboratorio sintético
   y solicita la ruta elegida. No recorras Fotos/iCloud u otras carpetas para
   descubrir material personal. No subas las imágenes a servicios externos.

5. Con fotos disponibles, evalúa vistas y coherencia de pose. Prepara copias
   orientadas y recortes sin modificar originales. Empieza por una prenda
   superior y una inferior. Crea máscaras revisables y un manifest.json para
   composición con dos puntos de alineación por capa. Marca los huecos que
   requieren otra foto; no presentes piel o prendas inventadas como captura.

6. En la ruta 3D, construye o adapta primero una malla sencilla con cuerpo y
   prendas separadas. La escena sintética sólo prueba el transporte y no
   representa a la usuaria. Usa referencias para ajustar proporciones y
   texturas; pide altura si se necesita escala métrica. Prepara una vista
   estática primero. Para animación posterior harán falta rig y pesos; para
   tela física, patrones y colisiones. No conviertas una malla fusionada de
   cuerpo y ropa en una promesa de prendas intercambiables.
   Exporta GLB y, cuando sea viable con herramientas locales de Apple, USDZ.
   Registra triángulos, texturas y tamaño; presupuesto exploratorio de
   30,000 triángulos y 20 MiB por conjunto, sujeto a pruebas reales.

7. Ejecuta model_audit.py antes de elegir modelo. Mobile-VTON tiene unos
   3.75 GB publicados; FASHN VTON 1.5 unos 1.94 GB más dependencias. Usa las
   revisiones registradas y revisa licencias. No uses la API comercial FASHN.
   Comprueba un camino de inferencia en MPS antes de cargar todo: tipos de
   datos, operadores, pose/parser y memoria máxima. No fuerces un pipeline
   CUDA-only en Metal. Si un componente necesita CUDA, registra ese bloqueo
   concreto y avanza con las otras rutas; no alquiles GPU automáticamente.

8. Si hay inferencia reproducible en la Mac, evalúa exportar módulos con
   coremltools, resolución fija y precisión compatible. Compara sus salidas
   con el modelo original antes de cuantizar. No declares soporte iPhone
   por haber convertido sólo un módulo: debe incluir preprocesamiento,
   codificadores, modelo, decodificador y postprocesamiento. No entrenes
   un LoRA ni realices destilación hasta demostrar que son necesarios.

9. Las mediciones de iPhone requieren compilación, firma y dispositivo real.
   Prepara una prueba local en la estructura iOS existente si las herramientas
   y el teléfono están disponibles. Conserva flutter_bloc/GetIt/GoRouter y
   packages/core en Dart puro. Mide memoria máxima, latencia en frío/caliente,
   fidelidad y comportamiento térmico; prueba también sin red.

10. Guarda fotos, resultados personales, pesos y binarios fuera de Git, en
    carpetas ignoradas. Versiona scripts, notas y medidas agregadas sin fotos.
    No despliegues, no fusiones main/develop y no hagas push --force. Entrega
    qué funciona, qué no, comandos reproducibles y fotos/medidas que falten.
```
