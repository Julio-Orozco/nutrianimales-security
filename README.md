# NutriAnimales · Monitoreo, seguridad y auditoría

Proyecto académico BCD 9220, Lead University. Implementación para cinco integrantes basada en la guía «Sistema de Monitoreo Proactivo, Seguridad y Hardening de Base de Datos». Datos completamente ficticios.

**Empezá por este README.** Después leé [COMANDOS](docs/COMANDOS.md), [ESCENARIOS](docs/ESCENARIOS.md) y [MATRIZ DE CUMPLIMIENTO](docs/CUMPLIMIENTO.md). La [guía navegable de código](docs/GUIA_CODIGO.html) reúne fuentes numeradas y explicaciones. [CODIGO](docs/CODIGO.md) explica el propósito, funcionamiento y elección de cada módulo.

## Qué incluye

- PostgreSQL 16 con ocho tablas empresariales, datos reproducibles, tres roles y cuenta `agente_ia` sin escritura.
- Auditoría de INSERT/UPDATE/DELETE en cuatro tablas; usuario de sesión, IP, fecha, JSON anterior/posterior y conteo por sentencia.
- 17 detectores R1–R5, H1–H5 y D1–D7. Cada uno tiene su propio flujo n8n y escenario de prueba.
- Bot Telegram por polling con catálogo de consultas, resúmenes Groq y rechazo de texto fuera del catálogo. No ejecuta SQL escrito por la IA.
- Bandeja persistente de alertas, reintentos y estado que distingue `pendiente`, `dry-run`, `fallida` y `enviada`.
- Nginx HTTPS, CA local, SCRAM, PostgreSQL sin puerto publicado y servicios de aplicación sin root.
- Backups cada cuatro horas, SHA-256 y prueba de restauración en otra base.
- Objetivo SSH aislado, pgAdmin, pgbench, pgBadger y extensión Filebeat → Logstash → Loki.
- Pruebas automáticas, CI para GitHub, reparto del trabajo, guía de exposición y plantilla de informe/evidencias.

**Límites importantes:** este código no contiene capturas ni mensajes de Telegram fabricados. El Viewer nativo de n8n requiere una edición que lo incluya; el panel alternativo no acredita ese requisito sin acuerdo docente. [VERIFICACION](docs/VERIFICACION.md) distingue lo comprobado aquí de lo pendiente de ejecución.

## Entorno recomendado

Ubuntu 24.04 en la computadora principal o en una VM. Estimación inicial: 4 CPU, 8 GB de RAM y 30 GB libres; reservar más memoria si se usa la extensión de logs. Docker Engine y Compose **2.24.4 o superior**, Python 3.12, OpenSSL y Git. Los comandos de este README se ejecutan en **terminal de Ubuntu**, desde la carpeta del proyecto; no pegarlos directamente en PowerShell.

Instalación oficial de Docker: https://docs.docker.com/engine/install/ubuntu/ . No se incluye un instalador descargado y ejecutado ciegamente como root. Si usás Windows, la opción preferida para evidenciar UFW y permisos es una VM Ubuntu; Docker Desktop permite ejecutar parte del stack, pero no convierte el firewall de Windows en UFW.

No requiere VPS, IP pública, dominio ni redirección de puertos del router. Telegram y Groq requieren Internet y tus propias credenciales. Un bot dedicado evita conflictos con webhooks de otros proyectos.

Si Ubuntu está en una VM, usar el navegador dentro de ella o el túnel SSH local explicado en COMANDOS. `localhost` en Windows y `localhost` dentro de la VM son equipos distintos.

## Arranque

### 1. Preparar secretos y certificados

```bash
python3 scripts/lab.py prepare
```

Genera `.env` con secretos aleatorios y permisos 600, una CA privada y un certificado con SAN para `localhost`/`postgres`. No sobrescribe secretos existentes. Se prefiere generar claves diferentes por instalación a distribuir una contraseña de ejemplo compartida.

### 2. Levantar servicios

```bash
python3 scripts/lab.py up
```

Construye las imágenes propias y espera disponibilidad. Solo Nginx publica `127.0.0.1:8080` y `127.0.0.1:8443`. La primera descarga/construcción puede superar cinco minutos; el objetivo de arranque reproducible debe medirse con imágenes previamente descargadas. No se promete un tiempo no medido.

Abrí **https://localhost:8443** y creá el propietario de n8n. Confiá en `.runtime/certs/ca.crt` en el navegador del laboratorio; es una CA local, no un certificado público. No compartás `ca.key` ni `server.key`. pgAdmin: **https://localhost:8443/pgadmin/**. Su email inicial es `ti@nutrianimales.test`; la contraseña aleatoria está en tu `.env` privado.

### 3. Configurar Telegram y Groq

```bash
python3 scripts/lab.py configure
```

Pide valores sin mostrarlos. Primero ingresá el token de un bot dedicado creado con BotFather; podés dejar los chats vacíos temporalmente. Enviá `/start` al bot desde Telegram y después ejecutá:

```bash
python3 scripts/lab.py telegram-chats
python3 scripts/lab.py configure --live
docker compose up -d --no-deps --force-recreate monitor
```

El primer comando muestra únicamente los identificadores de chat observados. El segundo guarda chat de alertas, chats autorizados y API key Groq, y desactiva `DRY_RUN` al tener los datos requeridos. El tercero recrea monitor para aplicar el entorno nuevo; `restart` no basta cuando cambian variables de entorno. No se borra la base.

### 4. Conectar UFW

El agente se ejecuta en **el Ubuntu dedicado al laboratorio**, no dentro de PostgreSQL ni en el Windows anfitrión. Primero configurá UFW según [COMANDOS](docs/COMANDOS.md). Después, desde otra terminal:

```bash
sudo python3 scripts/host_agent.py
```

Lee reglas y estado, envía hashes cada 30 segundos y nunca acepta órdenes remotas para cambiar el firewall. H1 devuelve «fuente no disponible» si este agente no está activo. La copia opcional de `ufw.log` no se inventa si Ubuntu no genera ese archivo.

### 5. Importar n8n

En n8n, creá una API key en Settings → n8n API y ejecutá:

```bash
python3 scripts/lab.py n8n-import
```

Pide esa clave sin imprimirla, crea una credencial HTTP cifrada e importa/activa 18 flujos: 17 alertas y el bot. Conserva los IDs en runtime: si una importación se interrumpe, se puede reanudar lo registrado sin crear otra copia de esos flujos. No sobrescribe ediciones hechas en el editor. Las credenciales Telegram/Groq viven en monitor; no aparecen en los JSON ni en los nodos.

### 6. Verificar y recoger evidencia

```bash
python3 scripts/lab.py status
python3 scripts/lab.py check all
python3 scripts/lab.py sql-demo audit
python3 scripts/lab.py backup
python3 scripts/lab.py restore-test
```

`check all` comprueba las fuentes y condiciones actuales; **sin hallazgo no significa que el escenario de ataque se haya ejecutado**. Algunas reglas consumen eventos incrementales: si n8n los procesó antes, revisá la bandeja y la ejecución correspondiente. Guardá las capturas reales siguiendo [EVIDENCIAS](docs/EVIDENCIAS.md).

## Reparto y entrega

[EQUIPO](docs/EQUIPO.md) reparte trabajo entre cinco; [EXPOSICION](docs/EXPOSICION.md) distribuye quince minutos. [INFORME](docs/INFORME.md) es una estructura para 15–20 páginas, que debe completarse con resultados reales. [PUBLICAR_GITHUB](docs/PUBLICAR_GITHUB.md) explica cada comando para crear el repositorio privado y subirlo.

El código es una base funcional para ejecutar y revisar. No convierte escenarios no ejecutados en pruebas aprobadas ni sustituye las credenciales, evidencias y participación del grupo.
