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

Open Grafana at `http://localhost:3000` and sign in with `admin` / `admin`.

The pre-provisioned dashboard is in the `Solar` folder as `Sungrow Realtime`.

Kiosk URL:

```bash
./scripts/kiosk-url.sh
```

Default output:

```text
http://localhost:3000/d/sungrow-realtime/sungrow-realtime?orgId=1&from=now-6h&to=now&refresh=5s&kiosk
```

You can change the display window or refresh rate:

```bash
TIME_RANGE=now-24h REFRESH=10s ./scripts/kiosk-url.sh
```

The dashboard currently uses the `sungrow` InfluxDB measurement and includes:

- Inverter temperature
- Current solar DC power
- Today and total yield
- Load power
- Grid import power, shown as a positive value
- MPPT 1/2 voltage and current
- Grid voltage and frequency
- Battery current, power, SOC, SOH, and temperature when exposed by the inverter

On this WLAN Modbus path, phase current registers and total active power returned Modbus illegal-address errors, so they are intentionally not polled.

The wrapper scripts use Compose too:

```bash
./scripts/start-poc.sh
./scripts/stop-poc.sh
```

## Check Telegraf

```bash
docker compose logs -f telegraf
```

Query latest values:

```bash
docker compose exec influxdb influx query --org solar --token solar-token 'from(bucket: "solar") |> range(start: -5m) |> filter(fn: (r) => r._measurement == "sungrow") |> last()'
```

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
