# Resumen Paso 0.1: Cierre de Brechas P0

## 1. Acciones Realizadas
- **Saneamiento de Secretos en Cliente (`lib/api_keys.dart`):**
  - Se eliminaron las claves hardcodeadas en texto plano de DeepSeek y OpenAI (`sk-7cb4...` y `sk-proj-lHxg...`).
  - Se sustituyeron las constantes por lecturas seguras de variables de entorno mediante `String.fromEnvironment('DEEPSEEK_API_KEY', defaultValue: '')` y `String.fromEnvironment('OPENAI_API_KEY', defaultValue: '')`. Esto preserva la compatibilidad con el resto del código y evita fallos estáticos cuando no se proveen valores en tiempo de compilación.
- **Ignorado de Archivos de Entorno (`.gitignore`):**
  - Se agregaron las entradas `.env`, `.env.*` y `*.env` a `.gitignore` para prevenir la inclusión inadvertida de secretos y variables locales al repositorio.
- **Aseguramiento de Reglas en Firestore (`firestore.rules`):**
  - Se corrigió la vulnerabilidad en la colección `wardrobe_items`, reemplazando la regla abierta `allow list: if signedIn();` por `allow list: if signedIn() && resource.data.userId == request.auth.uid;`, restringiendo las consultas únicamente a los documentos pertenecientes al usuario autenticado.
  - Se reforzó la regla de actualización (`update`), exigiendo que el usuario sea el dueño (`resource.data.userId == request.auth.uid`) y garantizando la inmutabilidad del campo de autoría mediante `request.resource.data.userId == resource.data.userId`.
- **Archivos Modificados:**
  - `lib/api_keys.dart`
  - `firestore.rules`
  - `.gitignore`
- **Archivos Creados:**
  - `PASO_0_1_RESUMEN.md`

---

## 2. Bloques de Código Clave

### `lib/api_keys.dart`
```dart
const String deepseekApiKey =
    String.fromEnvironment('DEEPSEEK_API_KEY', defaultValue: '');

const String openAiApiKey =
    String.fromEnvironment('OPENAI_API_KEY', defaultValue: '');
```

### `firestore.rules` (Sección `wardrobe_items`)
```firestore
    // Global wardrobe items collection (scoped by userId field)
    match /wardrobe_items/{itemId} {
      // Allow creating items only if userId matches authenticated user
      allow create: if signedIn() && request.resource.data.userId == request.auth.uid;
      
      // Allow reading individual documents if userId matches
      allow get: if signedIn() && resource.data.userId == request.auth.uid;
      
      // Allow list (queries) only if scoped to current user
      allow list: if signedIn() && resource.data.userId == request.auth.uid;
      
      // Allow updating only if owner and userId field is not altered
      allow update: if signedIn() && resource.data.userId == request.auth.uid && request.resource.data.userId == resource.data.userId;

      // Allow deleting if userId matches
      allow delete: if signedIn() && resource.data.userId == request.auth.uid;
    }
```

---

## 3. Estado de la Compilación y Tests

Se ejecutó el análisis estático utilizando FVM:

```bash
$ fvm flutter analyze
Analyzing AI-Fit...
No issues found! (ran in 1.8s)
```

- **Diagnóstico:** 0 errores, 0 advertencias, 0 lints rotos tras la sanitización de secretos y reestructuración de reglas.

---

## 4. Requerimientos de Acción Humana Inmediata (Checklist para el Desarrollador)

> [!CAUTION]
> Las claves API expuestas previamente en el repositorio deben considerarse comprometidas y requieren revocación manual inmediata.

- [ ] **Revocar y Rotar Clave API de DeepSeek:**
  - Acceder a la [Consola de DeepSeek](https://platform.deepseek.com/) -> API Keys.
  - Eliminar la clave expuesta (`sk-7cb4b02b...`) y generar una nueva clave si es requerida para el backend / Cloud Functions.
- [ ] **Revocar y Rotar Clave API de OpenAI:**
  - Acceder a [OpenAI Platform](https://platform.openai.com/api-keys).
  - Revocar la clave expuesta (`sk-proj-lHxg...`) y generar una nueva clave secreta.
- [ ] **Desplegar Reglas de Seguridad a Firebase:**
  - Ejecutar en la terminal de desarrollo:
    ```bash
    firebase deploy --only firestore:rules
    ```
  - Verificar en la [Consola de Firebase](https://console.firebase.google.com/) que las reglas de Cloud Firestore se hayan actualizado correctamente en producción.
- [ ] **Configurar Variables de Entorno en Compilación o Backend (si aplica):**
  - Si se ejecutan llamadas locales en desarrollo con Flutter: usar `--dart-define=DEEPSEEK_API_KEY=...` y `--dart-define=OPENAI_API_KEY=...`.
  - Nota arquitectural: según el plan de migración, estas claves deberán residir exclusivamente en Firebase Cloud Functions / Secret Manager en los siguientes pasos.
