### REST API documentation with Phoenix Swagger
This project uses [Phoenix Swagger](https://hexdocs.pm/phoenix_swagger/readme.html) to generate API documentation.

To check the API documentation, visit the Swagger UI at<br>
http://localhost:4000/docs/swagger

### Adding/Modifying swagger documentation
All the swagger definitions are placed in controllers. Two important things to take care of:
1. Swagger definitions at the starting of the controller
2. Docs for each endpoint function using `swagger_path` just above function definition
