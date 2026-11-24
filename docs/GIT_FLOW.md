# Git Flow de AI Fit

Configurado localmente el 2026-11-24 para investigar y desarrollar el probador con menor costo.

## Ramas y punto de partida

| Rama | Función | Estado inicial |
| --- | --- | --- |
| `main` | Base estable registrada en Git | `a511c54`; no equivale a una verificación del despliegue actual |
| `migration/jaspr-server-20261026` | Migración existente a monorepo Flutter/Jaspr | `7bc559a`; conserva su historial |
| `develop` | Base de integración para el trabajo nuevo | Creada desde `7bc559a`, que ya contiene la migración |
| `feature/local-first-tryon-research` | Investigación y propuesta del probador | Creada desde `develop` |

Se consultó `origin` mediante `git fetch origin --prune` antes de crear las ramas. El árbol estaba limpio. La creación de `develop` desde la migración conserva los cambios existentes sin fusionar ramas base. `main` y la rama de migración mantienen sus commits originales.

Las ramas nuevas y los commits de esta investigación son locales hasta que se publiquen explícitamente. La configuración `gitflow.*` está en `.git/config`, no se transmite al clonar. No se instaló la extensión `git-flow`; el flujo funciona con Git estándar.

## Convenciones

- `feature/<tema>` nace de `develop` para una investigación o cambio acotado.
- `release/<version>` se prepara desde `develop` cuando exista una entrega validada.
- `hotfix/<tema>` nace de la base de la versión afectada, normalmente `main`.
- Las etiquetas de versiones usan el prefijo `v`.
- No usar `push --force`. `AGENTS.md` prohíbe fusionar ramas base: preparar los cambios para revisión y no ejecutar automáticamente el cierre de release de Git Flow.

## Trabajo habitual

```bash
git status --short --branch
git switch develop
git switch -c feature/<tema>
# Editar y validar el alcance de esa rama.
git add <archivos-del-cambio>
git commit -m "feat: descripción concreta"
```

La rama de investigación contiene documentación, sin cambios funcionales ni despliegues. La implementación posterior puede separarse en ramas para captura, compositor local y evaluación de modelos. Antes de cada cambio se debe revisar el estado de `develop`; no asumir que contiene trabajo todavía pendiente de integración.

## Reproducir la configuración local

Estos valores describen la configuración aplicada. Un clon futuro debe crear o recuperar `develop` desde la referencia acordada antes de usarlos:

```bash
git config --local gitflow.branch.master main
git config --local gitflow.branch.develop develop
git config --local gitflow.prefix.feature feature/
git config --local gitflow.prefix.release release/
git config --local gitflow.prefix.hotfix hotfix/
git config --local gitflow.prefix.support support/
git config --local gitflow.prefix.versiontag v
```
