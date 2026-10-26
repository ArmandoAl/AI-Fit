/// Textos de UI en español (MVP). Valores de dominio (colores, tags) siguen en inglés en DB/IA.
class AppStringsEs {
  AppStringsEs._();

  // —— App / navegación ——
  static const appName = 'AIFit';
  static const navWardrobe = 'Armario';
  static const navStylist = 'Atelier';
  static const navProfile = 'Perfil';

  // —— Login ——
  static const loginTagline = 'Tu estilista personal';
  static const loginDescription =
      'Looks a medida con tu armario real. Inteligencia de moda, try-on virtual y un atelier en el bolsillo.';
  static const continueWithGoogle = 'Continuar con Google';
  static const signingIn = 'Iniciando sesión...';
  static const termsLine =
      'Al continuar, aceptas nuestros Términos de servicio y Política de privacidad.';

  // —— Armario ——
  static const myWardrobe = 'Armario';
  static const curateCloset = 'Colección personal';
  static const emptyWardrobeTitle = 'Tu closet espera';
  static const emptyWardrobeSubtitle =
      'Fotografía cada prenda. La IA la cataloga y arma looks con lo que ya tienes.';
  static const addFirstPiece = 'Añadir primera prenda';
  static const addToWardrobe = 'Añadir al armario';
  static const addToWardrobeSubtitle = 'Importa prendas a tu closet';
  static const chooseGallery = 'Elegir de la galería';
  static const chooseGallerySubtitle = 'Selecciona una o varias fotos';
  static const takePhoto = 'Tomar foto';
  static const takePhotoSubtitle = 'Captura la prenda con tu cámara';
  static const totalItems = 'PRENDAS';
  static const outfitsStat = 'OUTFITS';
  static const search = 'Buscar';
  static const noItemsFound = 'No hay prendas';
  static const noData = 'Sin datos';
  static const generateOutfitAi = 'Generar outfit con IA';
  static const filterAll = 'Todo';

  // —— Añadir prenda ——
  static const addItem = 'Añadir prenda';
  static String addItems(int n) => 'Añadir prendas ($n)';
  static const save = 'Guardar';
  static const selectImages = 'Seleccionar imágenes';
  static const noImagesSelected = 'No hay imágenes seleccionadas';
  static const itemDetails = 'Detalles de la prenda';
  static const typeRequired = 'Tipo *';
  static const subTypeRequired = 'Subtipo *';
  static const brandOptional = 'Marca (opcional)';
  static const fillRequiredFields = 'Completa todos los campos obligatorios';
  static const pleaseLogin = 'Inicia sesión para añadir prendas';
  static const itemsAddedSuccess = '¡Prendas añadidas correctamente!';
  static const errorAddingItems = 'Error al añadir prendas';

  // —— Detalle prenda ——
  static const editItem = 'Editar prenda';
  static const itemDetailsTitle = 'Detalles de la prenda';
  static const aiAnalysis = 'Análisis con IA';
  static const aiAnalysisDescription =
      'Analiza esta prenda con IA para detectar colores, etiquetas de estilo y temporada.';
  static const analyzeWithAi = 'Analizar con IA';
  static const analyzing = 'Analizando...';
  static const colors = 'Colores';
  static const styleTags = 'Estilo';
  static const season = 'Temporada';
  static const brand = 'Marca';
  static const itemUpdated = '¡Prenda actualizada!';
  static const errorUpdating = 'Error al actualizar';
  static const enterOutfitInstructions = 'Escribe instrucciones para el outfit';
  static const generateOutfitWithAi = 'Generar outfit con IA';
  static const outfitInstructionsHint =
      'Instrucciones (ej. "salida casual", "evento formal")';
  static const generateOutfit = 'Generar outfit';
  static const errorAnalyzing = 'Error al analizar la imagen';
  static const errorGeneratingOutfit = 'Error al generar el outfit';
  static const couldNotBuildOutfit =
      'No se pudo crear un outfit con tu armario actual.';

  // —— Estilista / chat ——
  static const aiStylist = 'Atelier';
  static const premiumStyling = 'Consulta privada';
  static const savedOutfits = 'Outfits guardados';
  static const quickGenerate = 'Generación rápida';
  static const describeOccasionHint =
      'Describe la ocasión, el estilo o los colores...';
  static const lookDetails = 'Detalle del look';
  static const stylistWelcome =
      'Hola — soy tu estilista personal. Cuéntame la ocasión, el estilo o los colores que tienes en mente y armaré looks con tu armario.';
  static const connectionError =
      'Tengo un problema de conexión — ¿puedes intentar de nuevo?';
  static const puttingLooksTogether =
      'Perfecto — estoy armando looks con tu armario.';
  static const couldNotBuildFullLook =
      'No pude armar un look completo con tu armario. Prueba ajustar colores u ocasión.';
  static const hereAreYourLooks = 'Aquí tienes tus looks seleccionados.';
  static const emptyWardrobeChat =
      'Tu armario está vacío. Añade prendas antes de generar outfits.';
  static const readyToStyleYou = 'Listo para vestirte';
  static const generateOutfitCta = 'Generar outfit';
  static const creatingLooks = 'Creando looks...';
  static const curatedLook = 'Look seleccionado';
  static String matchPercent(int percent) => '$percent% coincidencia';
  static String piecesFromWardrobe(int count) =>
      count == 1 ? '1 prenda de tu armario' : '$count prendas de tu armario';
  static String piecesShort(int count) =>
      count == 1 ? '1 prenda' : '$count prendas';

  // —— Generar outfit ——
  static const generateOutfitTitle = 'Generar outfit';
  static const generateOutfitSubtitle = 'Estilo por descripción';
  static const describeOutfitWant = 'Describe el outfit que quieres';
  static const outfitDescription = 'Descripción del outfit';
  static const enterOutfitDescription = 'Escribe una descripción del outfit';
  static const generatePreviewImage = 'Generar imagen de vista previa';
  static const generatePreviewSubtitle =
      'Genera la vista del primer look al instante; los demás quedan listos para try-on bajo demanda.';
  static const generateOutfitsButton = 'Generar outfits';
  static const analyzingRequest = 'Analizando tu solicitud...';
  static const filteringWardrobe = 'Filtrando tu armario...';
  static const generatingOutfits = 'Generando outfits...';
  static const creatingPreview = 'Creando vista previa...';
  static const processing = 'Procesando...';
  static const generatedOutfits = 'Outfits generados';
  static String outfitNumber(int n) => 'Outfit $n';
  static const itemsLabel = 'Prendas:';
  static const retryTryOn = 'Reintentar';
  static const generatingTryOnView = 'Generando vista try-on…';
  static const readyForTryOnHint =
      'Listo para try-on — pulsa el botón para generar la vista.';
  static const tryOnGenerating = 'Generando vista...';
  static const tryOnReady = 'Vista lista';
  static const tryOn = 'Probar look';

  // —— Outfits guardados ——
  static const myOutfits = 'Mis outfits';
  static const whyThisWorks = 'Por qué funciona';
  static const tags = 'Etiquetas';

  // —— Bienvenida ——
  static const skip = 'Omitir';
  static const next = 'Siguiente';
  static const getStarted = 'Empezar';
  static const tips = 'Consejos';
  static const uploadPhotos = 'Sube tus fotos';
  static const uploadPhotosDesc =
      'Fotos de cara y cuerpo para que la IA conozca tu estilo.';
  static const buildWardrobe = 'Arma tu armario';
  static const buildWardrobeDesc =
      'Fotografía tus prendas y deja que la IA las catalogue.';
  static const getRecommendations = 'Recibe recomendaciones';
  static const getRecommendationsDesc =
      'Outfits y try-on personalizados con lo que ya tienes.';

  // —— Perfil (completar EN restantes) ——
  static const profile = 'Perfil';
  static const bodyPhotos = 'Fotos de cuerpo';
  static const facePhotos = 'Fotos de rostro';
  static const saveProfile = 'Guardar perfil';
  static const deleteAccount = 'Eliminar cuenta';

  // —— Varios ——
  static const error = 'Error';
  static String errorWith(String msg) => 'Error: $msg';
  static const wearingThisLook = 'En este look';
  static const editItems = 'Editar prendas';
  static const outfitResult = 'Resultado del outfit';
  static const viewDetails = 'Ver detalle';
  static const generatedOutfit = 'Outfit generado';
  static const quickGenerator = 'Generador rápido';
}
