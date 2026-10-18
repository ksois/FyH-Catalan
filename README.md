# Fear & Hunger 1 — Traducció al català 🇮🇱 *català* / Traducción al catalán

Parche **autocontenido** que traduce al **català** *Fear & Hunger* (1) manteniendo intactos
los códigos de control del motor, el tono oscuro del juego y sin tocar scripts, condiciones
ni nombres internos.

> **⚠️ Aviso**: esto es un parche fan **no oficial**. Necesitas tener **Fear & Hunger 1**
> ya instalado. No incluye el juego ni contenido copyrighted del mismo: solo archivos de
> datos modificados (`data\*.json` + `js\plugins.js`) y los scripts del parcheador.

---

## 📥 Instalación (2 pasos)

1. **Descarga** `FyH_Catala_Patch.zip` desde [Releases](../../releases) y **descomprímelo donde quieras**
   (Escritorio, Descargas, otra unidad… da igual).
2. **Doble clic en `patch.bat`**.

Eso es todo. El parcheador busca tu instalación de Fear & Hunger automáticamente:

| Orden | Método |
|---|---|
| 1 | Ruta guardada de una ejecución anterior (`FyH_path.txt`) |
| 2 | Steam: registro de Windows (`HKCU\Software\Valve\Steam`, `HKLM\...\Valve\Steam`) + todas las bibliotecas de `steamapps\libraryfolders.vdf` |
| 3 | Rutas típicas: `Program Files (x86)\Steam`, unidades `D:`–`G:` (`\SteamLibrary`, `\Games`, `\Juegos`), **Escritorio** y **Descargas** |
| 4 | Si no aparece: se abre un **selector de carpetas** — sirve la raíz del juego o su subcarpeta `www\` |

La ruta detectada se guarda en `FyH_path.txt` junto al `.bat`, así que las siguientes veces
va directo. Puedes borrar ese archivo si mueves el juego.

> Funciona igual aunque la ruta contenga **espacios y `&`** (p. ej. `C:\Games\Fear & Hunger\www`).

## 📤 Desinstalación

Doble clic en **`unpatch.bat`**: restaura los archivos originales desde `backup_original_cat\`
(dentro de la carpeta del juego) y **verifica los hashes** contra la versión original.
Si no hay backup, no toca nada.

## 🛡️ Seguridad y versión del juego

Antes de tocar nada, el parcheador calcula el **SHA256** de 6 archivos clave
(`System.json`, `CommonEvents.json`, `plugins.js`, `Map001/011/175.json`) y lo compara:

- **Coincide con el original (ES)** → continúa.
- **Coincide con el parche (CA)** → avisa de que ya está parcheado y **no vuelve a hacer backup**.
- **No coincide** → avisa de que tu versión es distinta a la esperada y el parche podría
  romper el juego, y pide confirmación **S/N**.

Además:

- El backup (`backup_original_cat\`) **nunca se sobrescribe**: si ya existe, se conserva.
- El backup se verifica por hash nada más crearlo.
- Si la copia falla a medias, el juego se **restaura automáticamente** desde el backup.
- Pide permisos de administrador **solo** si la carpeta del juego no es escribible con tu usuario.

## ⚙️ Cómo funciona por dentro

```
FyH_Catala_Patch/
├── patch.bat            → portada; delega todo en el motor PowerShell
├── unpatch.bat          → restauración
├── LEEME.txt            → instrucciones resumidas (offline)
├── files/               → payload, misma estructura relativa que el juego
│   ├── data/*.json      → los diálogos e interfaces traducidos al català
│   └── js/plugins.js    → plugins del juego
└── tools/
    ├── fyh.ps1          → motor: detección, hashes, backup, robocopy, restauración
    ├── hashes.txt       → SHA256 de la versión original (ES) esperada
    └── hashes_patch.txt → SHA256 de los mismos archivos con el parche aplicado
```

El motor (`tools/fyh.ps1`, PowerShell puro, **sin dependencias externas** — nada de Python,
Node ni instalaciones) hace, en orden:

1. **Detección** de la instalación (tabla de arriba) y normalización a la carpeta que
   contiene `data\System.json` + `js\plugins.js`.
2. **Verificación de versión** por hashes (explicada arriba).
3. **Backup** de lo que se va a sobrescribir → `<juego>\backup_original_cat\`.
4. **Copia** del payload con `robocopy /E /IS /IT` (forzada, tolerante a timestamps) y
   comprobación del código de salida.
5. **Verificación posterior**: los hashes del juego deben coincidir con `hashes_patch.txt`;
   si no, restauración automática y aviso.
6. Mensaje final con `pause`; códigos de salida `0` = éxito, `2` = cancelado, `1` = error.

### Historia del proyecto (cómo se hizo la traducción)

- Punto de partida: el texto **en español** del juego (ver créditos).
- Extracción de las 178.184 cadenas de texto de los archivos `data\` a una memoria de
  traducción (TM) con códigos de control normalizados.
- Traducción a catalán con **glosario canónico** (`glossary.json`), revisión de
  consistencia terminológica y passes automáticos de puntuación/comillas.
- Verificación automática: paridad de códigos de control (`\C[n]`, `\N[n]`, `\|`, `%1`…),
  límites de longitud de línea, restos de español y balanceo de comillas.
- Resultado: **178.184 / 178.184 unidades traducidas (100 %)**, 0 discrepancias.

## 🧯 Problemas frecuentes

| Problema | Solución |
|---|---|
| No encuentra el juego | Bórralo/mueve nada: deja que llegue al selector y elige la carpeta del juego (o su `www\`). Si antes funcionaba, borra `FyH_path.txt`. |
| Pide permisos de administrador | Solo pasa si la carpeta no es escribible (p. ej. `Program Files`). Acepta el UAC. |
| "Tu versión no coincide" | Tu instalación es distinta de la base del parche (p. ej. copia en inglés de Steam). Puedes continuar bajo tu riesgo (S), pero puede romper el juego. |
| El antivirus se queja | Los `.bat`/`.ps1` son texto legible; revísalos si quieres. No descargan ni ejecutan nada externo. |
| Quiero volver al español | `unpatch.bat`. |

## 🙏 Créditos

- **[Miro Haverinen](https://mirohaver.itch.io/fear-and-hunger)** — creador de *Fear & Hunger* (2018).
  Compra el juego original; este parche no sustituye a ninguna compra.
- **Traducción fan al español de Fear & Hunger** — la base de texto sobre la que se ha
  construido esta versión catalana: todo el contenido parte de su trabajo de traducción.
  <!-- TODO: sustituir por el nombre del equipo/enlace exacto del parche español, p. ej.:
       Equipo: ... · Web: ... -->
- **Traducción al catalán** — proyecto de traducción ES→CA con glosario propio, revisión
  de consistencia y verificación automatizada de códigos de control.
- **Parcheador** — scripts batch/PowerShell originales de este proyecto (detección por
  Steam/VDF, verificación SHA256, backup seguro y auto-restauración).

## 📄 Notas legales

- Proyecto **no afiliado** a Miro Haverinen ni a las tiendas que distribuyen el juego.
- No se redistribuye ningún archivo original del juego: el parche solo contiene archivos
  de datos ya modificados por la traducción y scripts propios.
- Usas el parche bajo tu propia responsabilidad; el backup y la verificación por hashes
  existen precisamente para poder volver atrás siempre.

*Última actualización: octubre de 2026 · Estado de la traducción: 100 % (178.184 cadenas).*
