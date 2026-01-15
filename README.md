# Dbservice

A Phoenix-based database service application with LiveView UI for data imports and comprehensive API documentation.

## Quick Start

To set up this project locally, visit the [installation steps](./docs/INSTALLATION.md).

## Development

### Running the Application

**For macOS users:**
```bash
./start_server_macos.sh
```

**For Windows/Linux users or manual setup:**
```bash
mix phx.server
```

Visit [`localhost:4000`](http://localhost:4000) to access the application.

**Note**: macOS users can also use the convenient alias `dbservice` from anywhere in the terminal.

### API Documentation
Access the Swagger documentation at: `http://localhost:4000/docs/swagger/index.html`

**Note**: The macOS startup script automatically generates Swagger documentation. **Windows/Linux users** should run `mix phx.swagger.generate` once before accessing the API docs. For more details about API documentation setup, see [API Documentation Guide](./docs/SWAGGER.md).

### Database Management
For database operations like fetching data from production/staging:

**macOS/Linux users:**
```bash
./utils/fetch-data.sh
```

**Windows users:**
```bash
bash utils/fetch-data.sh
```

See [Database Utils Guide](./utils/README.md) for setup and configuration.

### Assigning Programs to Schools

To assign `program_ids` to schools based on school category and codes, run:

```bash
./utils/assign_school_programs.sh [local|staging|production]
```

This script assigns:
- **JNV NVS** program to all JNV schools (except 8 excluded UDISE codes)
- **JNV CoE** program to 18 Centre of Excellence schools
- **JNV Nodal** program to 13 Nodal schools (2025-26)

**Note:** This script has likely already been run on production/staging. Running it again is safe (idempotent) but unnecessary.

## Documentation

- **[Installation Guide](./docs/INSTALLATION.md)** - Complete setup instructions
- **[Deployment Guide](./docs/DEPLOYMENT.md)** - Production deployment guidelines  
- **[API Documentation](./docs/SWAGGER.md)** - REST API documentation with Phoenix Swagger

## Learn More

- **Phoenix Framework**: https://www.phoenixframework.org/
- **Guides**: https://hexdocs.pm/phoenix/overview.html
- **Documentation**: https://hexdocs.pm/phoenix
- **Community Forum**: https://elixirforum.com/c/phoenix-forum
- **Source Code**: https://github.com/phoenixframework/phoenix