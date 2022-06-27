### REST API documentation with Phoenix Swagger
This project uses [Phoenix Swagger](https://hexdocs.pm/phoenix_swagger/readme.html) to generate API documentation.

To check the API documentation, visit the Swagger UI at<br>
http://localhost:4000/docs/swagger


### Creating Swagger JSON schema
Swagger JSON schema compilation has been added to the in-built Phoenix compiler, meaning that it would also compile the swagger definitions upon detecting code updates. However, if you want to create/refresh JSON schema manually, run the following command:
```sh
mix phx.swagger.generate
```

### Adding/Modifying swagger documentation
All the swagger definitions are placed in controllers. Two important things to take care of:
1. Swagger definitions at the starting of the controller
2. Docs for each endpoint function using `swagger_path` just above function definition
