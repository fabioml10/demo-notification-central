FROM ruby:3.4.7
WORKDIR /app
COPY . .
RUN gem install sinatra json net-http rackup puma faye-websocket thin
EXPOSE 3000
ENTRYPOINT []
CMD ["ruby", "app.rb"]
