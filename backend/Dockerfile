FROM ruby:3.4.7
WORKDIR /app
COPY . .
RUN gem install sinatra json rackup puma
EXPOSE 3001
ENTRYPOINT []
CMD ["ruby", "app.rb"]
