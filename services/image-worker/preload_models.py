from sentence_transformers import SentenceTransformer

print("⏳ [preload_models] Precargando modelo CLIP 'clip-ViT-B-32'...")
SentenceTransformer('clip-ViT-B-32')

print("✅ Modelos precargados exitosamente en la imagen.")
