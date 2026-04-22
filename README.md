# MariaDB on Alpine Linux — Docker Image

A lightweight [MariaDB](https://mariadb.org/) Docker image built on top of [Alpine Linux](https://alpinelinux.org/),
inspired by [yobasystems/alpine-mariadb](https://github.com/yobasystems/alpine-mariadb).  

For the official MariaDB image maintained by the MariaDB developer community, see [hub.docker.com/_/mariadb](https://hub.docker.com/_/mariadb).

This Image on dockerhub: [https://hub.docker.com/r/44934045/mariadb_alpine](https://hub.docker.com/r/44934045/mariadb_alpine)

## Overview

| Component    | Version            |
| ------------ | ------------------ |
| Alpine Linux | latest (≥ 3.23.4)  |
| MariaDB      | latest (≥ 11.4.10) |

**Key characteristics:**

- Runs under the unprivileged `mysql` user (`uid=1002`, `gid=1000` by default — both adjustable via environment variables).
- Minimal footprint: only what is needed to run MariaDB is included.
- Automatically executes initialization scripts on first boot (see [Initialization Scripts](#initialization-scripts)).

---

## Volumes

| Mount path       | Purpose                                    |
| ---------------- | ------------------------------------------ |
| `/var/lib/mysql` | Database data files                        |
| `/etc/my.cnf.d`  | Configuration files and X.509 certificates |

---

## Environment Variables

| Variable              | Required | Default           | Description                                                                                          |
| --------------------- | -------- | ----------------- | ---------------------------------------------------------------------------------------------------- |
| `MYSQL_ROOT_PASSWORD` | No       | *(random)*        | Root password. If omitted on a fresh install, a random password is generated and printed to the log. |
| `MYSQL_DATABASE`      | No       | —                 | Name of the database to create on first boot.                                                        |
| `MYSQL_USER`          | No       | —                 | Application user granted full access to `MYSQL_DATABASE`. Requires `MYSQL_DATABASE` to be set.       |
| `MYSQL_PASSWORD`      | No       | —                 | Password for `MYSQL_USER`.                                                                           |
| `MYSQL_CHARSET`       | No       | `utf8`            | Default character set for the created database.                                                      |
| `MYSQL_COLLATION`     | No       | `utf8_general_ci` | Default collation for the created database.                                                          |
| `PUID`                | No       | `1002`            | UID to run the `mysql` service user as.                                                              |
| `PGID`                | No       | `1000`            | GID to run the `mysql` service user as.                                                              |
| `TZ`                  | No       | `UTC`             | Container timezone (e.g. `America/Toronto`).                                                         |
| `VERBOSE`             | No       | `0`               | Set to `1` for more detailed startup logs.                                                           |

> **Note:** `MYSQL_USER` is only created when `MYSQL_DATABASE` is also defined.  
> All variables that affect database creation are **evaluated only on the first boot**, when `/var/lib/mysql/mysql` does not yet exist.

---

## Initialization Scripts

On the **first boot only**, any files placed in `/docker-entrypoint-initdb.d/` are automatically executed
after the initial database setup, in **alphabetical order**. Supported file types:

| Extension | Behaviour                                                                           |
| --------- | ----------------------------------------------------------------------------------- |
| `.sh`     | Executed as a shell script. Has full access to all container environment variables. |
| `.sql`    | Imported directly into MariaDB.                                                     |
| `.sql.gz` | Decompressed on the fly and imported into MariaDB.                                  |

Files with any other extension are silently ignored.

**How it works internally:**

1. After the bootstrap phase, a temporary `mysqld` instance is started on a local Unix socket (no TCP port is exposed).
2. The container waits until the server is ready to accept connections (up to 30 seconds).
3. Each file in `/docker-entrypoint-initdb.d/` is processed in order.
4. The temporary server is shut down gracefully before the final `mysqld` process starts.

If `MYSQL_DATABASE` is defined, SQL scripts are executed with that database pre-selected — useful for dumps
that do not contain a `USE <database>;` statement.

**Example — mounting an init directory:**

```bash
docker run -d \
  --name mariadb \
  -e MYSQL_ROOT_PASSWORD="Hard2Gue$$Password" \
  -e MYSQL_DATABASE=myapp \
  -e MYSQL_USER=myuser \
  -e MYSQL_PASSWORD=mypassword \
  -v /your_data_dir:/var/lib/mysql \
  -v /your_init_dir:/docker-entrypoint-initdb.d \
  -p 3306:3306 \
  etaylashev/mariadb
```

> Files inside `/docker-entrypoint-initdb.d/` are only executed once.  
> On subsequent container starts the directory is ignored because the data volume already exists.

---

## Usage

### Creating a New Instance

```bash
docker run -d \
  --name mariadb \
  -e VERBOSE=1 \
  -e MYSQL_ROOT_PASSWORD="Hard2Gue$$Password" \
  -e MYSQL_DATABASE=myapp \
  -e MYSQL_USER=myuser \
  -e MYSQL_PASSWORD=mypassword \
  -v /your_data_dir:/var/lib/mysql \
  -p 3306:3306 \
  44934045/mariadb_alpine
```

### Running with an Existing Database

```bash
docker run -d \
  --name mariadb \
  -e VERBOSE=1 \
  -v /your_config_dir:/etc/my.cnf.d \
  -v /your_data_dir:/var/lib/mysql \
  -p 3306:3306 \
  etaylashev/mariadb
```

### Interactive MySQL Shell

```bash
docker exec -it mariadb sh -c "exec mysql -u root -p"
```

### Copy Default Configuration Files from the Container

```bash
docker cp mariadb:/etc/my.cnf.d/* ./config/
```

---

## Kubernetes / Pod Deployment

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: mariadb
  namespace: default
  labels:
    app: mariadb
    purpose: database
spec:
  volumes:
    - name: maria-conf
      hostPath:
        path: /data/mariadb/conf
    - name: maria-data
      hostPath:
        path: /data/mariadb/db
  containers:
    - name: mariadb
      image: etaylashev/mariadb
      env:
        - name: VERBOSE
          value: "1"
        - name: MYSQL_ROOT_PASSWORD
          value: "Hard2Gue$$Password"
        - name: MYSQL_DATABASE
          value: myapp
        - name: MYSQL_USER
          value: myuser
        - name: MYSQL_PASSWORD
          value: mypassword
      volumeMounts:
        - name: maria-conf
          mountPath: /etc/my.cnf.d
        - name: maria-data
          mountPath: /var/lib/mysql
      ports:
        - containerPort: 3306
          protocol: TCP
```

---

## TLS / Encrypted Connections

Copy your certificate and key files into the configuration volume (e.g. `/data/mariadb/conf`) and add the
following to a file named `server.cnf` in that directory:

```ini
[server]
ssl=on
ssl-ca=/etc/my.cnf.d/ca-chain.pem
ssl-cert=/etc/my.cnf.d/server.crt
ssl-key=/etc/my.cnf.d/server.key
```

Connect a client over TLS:

```bash
mysql -h <host> --ssl -u root -p
```

Verify the connection and cipher in use:

```sql
MariaDB [(none)]> STATUS;
-- Look for a line such as:
-- SSL: Cipher in use is TLS_AES_256_GCM_SHA384
```

For more information, refer to the [MariaDB Secure Connections documentation](https://mariadb.com/kb/en/secure-connections-overview/).

---

## Backup

### Using `mysqldump`

```bash
export MYSQL_ROOT_PASSWORD="Hard2Gue$$Password"

docker exec mariadb sh -c \
  "exec mysqldump --all-databases -uroot -p\"$MYSQL_ROOT_PASSWORD\"" \
  > /backup/all_databases.sql
```

To back up a single database:

```bash
docker exec mariadb sh -c \
  "exec mysqldump myapp -uroot -p\"$MYSQL_ROOT_PASSWORD\"" \
  > /backup/myapp.sql
```

Or use the included sample script `backup.sh` (edit it to match your environment before running).

---

## Restore

```bash
export MYSQL_ROOT_PASSWORD="Hard2Gue$$Password"

docker exec -i mariadb sh -c \
  "exec mysql -uroot -p\"$MYSQL_ROOT_PASSWORD\"" \
  < /backup/all_databases.sql
```

Or use the included sample script `restore.sh`.

---

## Upgrade

Upgrading between major MariaDB versions can be complex. Always read the
[official upgrade documentation](https://mariadb.com/kb/en/upgrading-between-major-mariadb-versions/) first.

As a general guideline:

1. Back up all databases (see [Backup](#backup)).
2. Pull the new image version.
3. Start the container pointing to the existing data volume.
4. Run `mysql_upgrade` to update the system tables:

```bash
export MYSQL_ROOT_PASSWORD="Hard2Gue$$Password"

docker exec -it mariadb sh -c \
  "exec mysql_upgrade -uroot -p\"$MYSQL_ROOT_PASSWORD\""
```

---

## License

This project is provided as-is under the [MIT License](LICENSE).
