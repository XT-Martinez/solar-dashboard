# Sungrow realtime monitoring PoC

This proof of concept polls the Sungrow inverter over local Modbus TCP, stores readings in InfluxDB, and shows them in Grafana.

Default target:

- Inverter IP: `192.168.254.152`
- Modbus TCP port: `502`
- Slave ID: `1`
- Poll interval: `5s`
- Inside temperature register: `5007` client address, equivalent to Sungrow register `5008` when the client uses zero-based addressing

## Start with Compose

```bash
cp .env.example .env
docker compose up -d
```

Open Grafana at `http://localhost:3500` and sign in with `admin` / `admin`.

The pre-provisioned dashboard is in the `Solar` folder as `Sungrow Realtime`.

Only Grafana is exposed to the host. InfluxDB is reachable from Grafana and Telegraf inside the shared Compose network namespace, but port `8086` is not published.

Kiosk URL:

```bash
./scripts/kiosk-url.sh
```

Default output:

```text
http://localhost:3500/d/sungrow-realtime/sungrow-realtime?orgId=1&from=now-6h&to=now&refresh=5s&kiosk
```

You can change the display window or refresh rate:

```bash
TIME_RANGE=now-24h REFRESH=10s ./scripts/kiosk-url.sh
```

The dashboard currently uses the `sungrow` InfluxDB measurement and includes:

- Inverter and battery temperature
- Current solar DC power
- Solar yield for the selected Grafana time range
- Grid consumption for the selected Grafana time range
- Battery consumption for the selected Grafana time range
- Load power
- Grid import power, shown as a positive value
- MPPT 1/2 voltage and current, with separate voltage/current axes
- Grid voltage, with zero-valued phases hidden
- Grid frequency
- Battery power and SOC when exposed by the inverter

On this WLAN Modbus path, phase current registers and total active power returned Modbus illegal-address errors, so they are intentionally not polled.

The battery fields currently read `0` when no battery is installed or when the inverter does not expose battery data over this Modbus path.

The wrapper scripts use Compose too:

```bash
./scripts/start-poc.sh
./scripts/stop-poc.sh
```

## Start at Login with Systemd

On Bazzite, this stack can run as a user systemd service against the user Podman socket:

```bash
mkdir -p ~/.config/systemd/user
cp systemd/solar-dashboard-compose.user.service ~/.config/systemd/user/solar-dashboard-compose.service
systemctl --user daemon-reload
systemctl --user enable --now solar-dashboard-compose.service
```

To start it at boot before login, enable linger once:

```bash
sudo loginctl enable-linger "$USER"
```

For a rootful Docker setup, install `systemd/solar-dashboard-compose.service` under `/etc/systemd/system/` instead.

## Check Telegraf

```bash
docker compose logs -f telegraf
```

Query latest values:

```bash
docker compose exec influxdb influx query --org solar --token solar-token 'from(bucket: "solar") |> range(start: -5m) |> filter(fn: (r) => r._measurement == "sungrow") |> last()'
```

InfluxDB is intentionally not exposed on `localhost:8086`; use `docker compose exec influxdb ...` for database inspection.

## Configure InfluxDB Retention

Compose runs `configure-retention` automatically when the stack starts. By default, it keeps raw `solar` samples for 90 days and writes 1-minute averages to `solar_1m` for 2 years.

You can also rerun the setup manually:

```bash
docker compose run --rm configure-retention
```

Override the retention settings in `.env` or before running the Compose service:

```bash
INFLUX_RAW_RETENTION=2160h \
INFLUX_DOWNSAMPLED_BUCKET=solar_1m \
INFLUX_DOWNSAMPLED_RETENTION=17520h \
docker compose run --rm configure-retention
```

The setup is safe to rerun. It updates the raw bucket retention, creates or updates the downsampled bucket, and creates or updates the `downsample-solar-1m` task.

If the dashboard is empty or the value is clearly wrong, try the non-offset register:

```bash
INSIDE_TEMP_REGISTER=5008 docker compose up -d --force-recreate telegraf
```

## Change target or poll rate

```bash
INVERTER_HOST=192.168.254.152 POLL_INTERVAL=10s docker compose up -d
```

The default `5s` poll interval is a good balance for this WiNet WLAN setup. Polling every second would still be modest storage-wise, but it creates five times more Modbus traffic and WiNet has already shown sensitivity to concurrent or rapid requests.

## Stop

```bash
docker compose down
```

Compose removes the containers but leaves the InfluxDB and Grafana volumes so you do not lose collected samples. Use `docker compose down -v` only if you intentionally want to delete the collected samples and Grafana state.
