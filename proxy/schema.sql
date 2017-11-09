CREATE TABLE IF NOT EXISTS proxies (
	proxy_id INTEGER PRIMARY KEY,
	/* An address */
	proxy_address TEXT UNIQUE,
	/* A timestamp of a insert */
	proxy_added TIMESTAMP,
	/* A timestamp of the last check */
	proxy_checked TIMESTAMP,
	/* A reference to a source */
	proxy_source TEXT
);

CREATE INDEX IF NOT EXISTS proxies_checked_idx ON proxies (proxy_checked);

CREATE TABLE IF NOT EXISTS checks (
	check_proxy INTEGER REFERENCES proxies (proxy_id),
	/* A timestamp of the attempt */
	check_timestamp TIMESTAMP,
	/* A check result: 0 - not working, 1 - working */
	check_status INTEGER,
	/* -1 - Unknown, 0 - HTTP, 1 - SOCKS4, 2 - SOCKS5, 3 - Web Proxy */
	check_type INTEGER,
	/* An address of the proxy */
	check_address TEXT,
	PRIMARY KEY(check_proxy, check_timestamp)
);

CREATE TABLE IF NOT EXISTS sessions (
	/* A session identifier of a check */
	session_id TEXT PRIMARY KEY,
	/* An address of the checked proxy */
	session_address TEXT
);

CREATE TABLE IF NOT EXISTS blocks (
	block_id INTEGER PRIMARY KEY,
	block_address TEXT UNIQUE,
	block_start TIMESTAMP,
	block_expiry TIMESTAMP
);

CREATE TABLE IF NOT EXISTS settings (
	name TEXT PRIMARY KEY,
	value TEXT
);
