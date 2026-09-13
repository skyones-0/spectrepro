# Publicar un release de Spectre Pro

Esta guía describe el ciclo completo de entrega de Spectre Pro para macOS:
desde un cambio de código hasta que una instalación anterior detecta la nueva
versión mediante **Check for Updates…**.

## Resultado esperado

Un release publicado contiene:

- `SpectrePro.dmg` para instalar la aplicación.
- `SpectrePro-macos-universal.zip` como archivo alternativo.
- `appcast.xml`, firmado por Sparkle, para que la app encuentre la actualización.
- `SHA256SUMS.txt` para verificar los archivos descargados.
- Un SBOM SPDX y attestation de procedencia generados por GitHub Actions.

## Antes de empezar

Necesitas:

- Acceso de escritura a `skyones-0/spectrepro`.
- Zig `0.16.0` y Xcode instalados para validar localmente.
- Tu YubiKey disponible para firmar commits y tags con Git.
- Los secretos `SPECTREPRO_SPARKLE_PRIVATE_KEY` y
  `SPECTREPRO_SPARKLE_PUBLIC_KEY` configurados en GitHub Actions. Solo son
  necesarios para publicar; no se guardan en el repositorio.
- Los secretos de firma Apple `SPECTREPRO_APP_SIGNING_CERTIFICATE_BASE64`,
  `SPECTREPRO_APP_SIGNING_CERTIFICATE_PASSWORD` y
  `SPECTREPRO_APP_SIGNING_IDENTITY`. El certificado debe ser siempre el mismo
  para que macOS conserve permisos como Accessibility entre actualizaciones.

Comprueba el estado inicial:

```bash
git switch main
git pull --ff-only origin main
git status
```

El resultado debe indicar un árbol de trabajo limpio antes de crear una rama.

## 1. Planificar el cambio

1. Crea un Issue en el repositorio que explique el objetivo y sus criterios de
   aceptación.
2. Añádelo al [Project de Spectre Pro](https://github.com/users/skyones-0/projects/2).
3. Define `Priority`, `Area` y la versión objetivo en el campo `Release`.
4. Mueve la tarjeta a `In Progress` cuando empieces.

Ejemplo: un problema visual pequeño puede pertenecer a `macOS UI` y a la
versión `1.0.4`.

## 2. Crear una rama y desarrollar

Para un cambio normal, trabaja en una rama descriptiva:

```bash
git switch -c fix/update-overlay-layout
```

Haz el cambio y conserva el alcance limitado al Issue. Antes de hacer commit,
revisa los archivos modificados:

```bash
git diff --check
git status
```

## 3. Validar localmente

Empieza por la comprobación más específica y luego valida la aplicación:

```bash
# Core y pruebas Zig
zig build -Demit-macos-app=false
zig build test

# Aplicación macOS sin firma de distribución
xcodebuild \
  -project macos/SpectrePro.xcodeproj \
  -scheme SpectrePro \
  -configuration Debug \
  -derivedDataPath /tmp/spectrepro-derived \
  CODE_SIGNING_ALLOWED=NO \
  test
```

No ignores un fallo de estas pruebas para publicar una versión. Corrige el
problema, vuelve a validar y documenta cualquier limitación real en el Issue.

## 4. Preparar el número de versión

Spectre Pro usa versiones semánticas: `MAJOR.MINOR.PATCH`.

- `PATCH` (`1.0.3` → `1.0.4`): correcciones compatibles, como un fallo visual.
- `MINOR` (`1.0.4` → `1.1.0`): funcionalidad nueva compatible.
- `MAJOR` (`1.1.0` → `2.0.0`): cambios incompatibles o una nueva etapa de producto.

Actualiza el mismo número sin la `v` en estos archivos:

```text
build.zig.zon
macos/SpectrePro.xcodeproj/project.pbxproj
```

Verifica que no queden valores distintos:

```bash
rg 'version = "1\.0\.4"|MARKETING_VERSION = 1\.0\.4' \
  build.zig.zon macos/SpectrePro.xcodeproj/project.pbxproj
```

Sustituye `1.0.4` por la versión que vayas a publicar.

## 5. Firmar y subir el cambio

Todos los cambios que subas deben estar firmados por tu llave de Git asociada a
la YubiKey. Haz el commit con `-S`; Git pedirá la interacción de la llave si es
necesaria.

```bash
git add <archivos-cambiados>
git commit -S -m "fix: describe el cambio"
git verify-commit HEAD
git push -u origin fix/update-overlay-layout
```

`git verify-commit HEAD` debe mostrar una firma válida de tu identidad. No
compartas PIN, claves privadas ni secretos de Sparkle en commits, Issues o
logs.

## 6. Abrir Pull Request y esperar los controles

Abre un Pull Request desde tu rama hacia `main`, enlázalo al Issue y espera los
checks. En un Pull Request se ejecutan:

| Workflow | Qué verifica |
| --- | --- |
| `macOS CI` | Compila el core Zig, ejecuta pruebas Zig y de macOS, y valida el bundle `.app`. |
| `CodeQL C/C++` | Busca patrones de seguridad en el código nativo. |
| `Workflow Lint` | Revisa la sintaxis y las prácticas de los workflows. |
| `Dependency Review` | Revisa cambios de dependencias introducidos por el PR. |

No integres el cambio hasta que los checks aplicables estén en verde. Corrige
los fallos en la misma rama, vuelve a firmar el nuevo commit y vuelve a subirlo.

### Integrar conservando firmas

Para un proyecto personal, puedes integrar de forma fast-forward después de
que el PR esté aprobado y verde. Así el commit firmado de tu rama llega intacto
a `main`:

```bash
git switch main
git pull --ff-only origin main
git merge --ff-only fix/update-overlay-layout
git push origin main
```

El PR se cerrará automáticamente cuando GitHub detecte que los commits llegaron
a `main`. Si usas el botón de merge de GitHub, revisa qué identidad de firma usa
GitHub antes de depender de esa firma para tu política personal.

## 7. Esperar CI en `main`

Cada push a `main` vuelve a ejecutar:

- `macOS CI`
- `CodeQL C/C++`
- `Workflow Lint`

Consulta el estado con:

```bash
gh run list --repo skyones-0/spectrepro --branch main --limit 10
```

El release solo se etiqueta cuando `macOS CI` está correcto. Si falla, crea un
nuevo commit firmado con la corrección, súbelo y espera otra ejecución verde.

## 8. Crear el tag firmado

Cuando `main` esté verde, crea el tag anotado y firmado. El tag tiene el prefijo
`v`, pero los archivos del proyecto no.

```bash
git switch main
git pull --ff-only origin main
git status

git tag -s v1.0.4 -m "Spectre Pro 1.0.4"
git tag -v v1.0.4
git push origin v1.0.4
```

La comprobación `git tag -v v1.0.4` debe confirmar la firma de tu YubiKey. No
reutilices, borres ni muevas un tag publicado; si detectas un problema después
de publicar, prepara un nuevo `PATCH`.

## 9. Qué hace GitHub Actions al recibir el tag

El tag `v1.0.4` inicia **Personal macOS Release**. El workflow:

1. Comprueba el formato del tag y los secretos de Sparkle.
2. Compila el core Zig en modo `ReleaseFast`.
3. Construye `Spectre Pro.app` y actualiza sus metadatos de release.
4. Importa temporalmente el certificado Apple desde los secretos y firma la
   aplicación con la identidad configurada.
5. Verifica la firma y el identificador `co.skyones.spectrepro`.
6. Crea el DMG y el ZIP.
7. Firma el DMG para Sparkle y genera `appcast.xml`.
8. Genera SHA-256, SBOM y attestations.
9. Publica los assets en GitHub Releases.
10. Descarga de nuevo los assets publicados, verifica los checksums y valida el
   XML y la firma del appcast.

Sigue la ejecución con:

```bash
gh run list --repo skyones-0/spectrepro \
  --workflow "Personal macOS Release" --limit 3

gh run watch <RUN_ID> --repo skyones-0/spectrepro --exit-status
```

## 10. Verificar el release publicado

Cuando el workflow termina correctamente:

```bash
gh release view v1.0.4 --repo skyones-0/spectrepro
gh release download v1.0.4 --repo skyones-0/spectrepro \
  --pattern 'SHA256SUMS.txt' \
  --pattern 'appcast.xml'
shasum -a 256 -c SHA256SUMS.txt
```

Confirma en GitHub Releases que estén el DMG, ZIP, appcast, checksums y SBOM.
Después instala una versión anterior en una Mac de prueba y selecciona **Spectre
Pro → Check for Updates…**. Debe descubrir la versión nueva, descargarla y
reabrir la app actualizada.

La distribución actual es personal: el appcast y la aplicación usan firmas
criptográficas, pero el DMG no usa Developer ID ni notarización de Apple. Es
normal que la primera instalación manual requiera aprobación en macOS.

## 11. Cerrar el trabajo

1. Marca las casillas de aceptación del Issue.
2. Mueve la tarjeta del Project a `Done`.
3. Añade al Issue el enlace del release y el resultado de la prueba de
   actualización.
4. Planifica el siguiente cambio en una nueva Issue y nueva versión objetivo.

## Si algo falla

| Situación | Acción correcta |
| --- | --- |
| Fallo de pruebas o CodeQL | Corrige el código, crea otro commit firmado y espera CI verde. |
| Fallo del release antes de publicar | Corrige la causa y vuelve a ejecutar el workflow para el tag existente solo si ningún asset fue publicado. |
| Release publicado con un defecto | No reescribas el tag. Incrementa `PATCH`, corrige y publica un tag nuevo. |
| La app no detecta el release | Verifica que el release contenga `appcast.xml`, que su firma sea válida y que la app instalada sea una versión anterior. |
| Git no acepta la firma | Conecta/desbloquea la YubiKey y ejecuta de nuevo el commit o tag; nunca sustituyas la firma por una clave privada compartida. |
