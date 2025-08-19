# Dbservice

A Phoenix-based database service application with LiveView UI for data imports and comprehensive API documentation.

## Quick Start

To set up this project locally, visit the [installation steps](./docs/INSTALLATION.md).

## Development

### Running the Application
```bash
./start_server.sh
```

Visit [`localhost:4000`](http://localhost:4000) to access the application.

### API Documentation
Access the Swagger documentation at: `http://localhost:4000/docs/swagger/index.html`

**Note**: The startup script automatically generates Swagger documentation. For more details about API documentation setup, see [API Documentation Guide](./docs/SWAGGER.md).

### Database Management
For database operations like fetching data from production/staging:
```bash
./utils/fetch-data.sh
```

See [Database Utils Guide](./utils/README.md) for setup and configuration.

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