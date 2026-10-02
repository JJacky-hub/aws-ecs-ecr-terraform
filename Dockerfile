FROM nginx:alpine
RUN echo "<h1>Hello from AWS ECS Fargate!</h1>" > /usr/share/nginx/html/index.html
EXPOSE 80
