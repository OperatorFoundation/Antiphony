# Antiphony

### To generate new client / server configs ###

Antiphony uses the 'ArgumentParser' library to parse and execute command line arguments.

From the Antiphony directory in your macOS / Linux command line terminal;

• To see what subcommands you have available to you:

$ swift run

```
example print out
USAGE: antiphony <subcommand>

OPTIONS:
  -h, --help              Show help information.

SUBCOMMANDS:
  new
  run

  See 'antiphony help <subcommand>' for detailed help.
```
===

• To create new client / server configs:

$ swift run antiphony new <exampleConfigName> <port>

```
Wrote config to ~/antiphony-server.json
Wrote config to ~/antiphony-client.json
```
===

• To run the server:

$ swift run antiphony run

```
...
Server started 🚀
Server listening 🪐
...
```
