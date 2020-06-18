FROM ruby:2.5.1-alpine AS build-env

ARG RAILS_ROOT=/app
ARG BUILD_PACKAGES="build-base curl-dev git"
ARG DEV_PACKAGES="postgresql-dev yaml-dev zlib-dev nodejs yarn"
ARG RUBY_PACKAGES="tzdata"

ENV RAILS_ENV=development
ENV NODE_ENV=development
ENV BUNDLE_APP_CONFIG="$RAILS_ROOT/.bundle"

WORKDIR $RAILS_ROOT

# install packages
RUN apk update \
    && apk upgrade \
    && apk add --update --no-cache $BUILD_PACKAGES $DEV_PACKAGES $RUBY_PACKAGES

COPY Gemfile*  ./

# install rubygem
COPY Gemfile Gemfile.lock $RAILS_ROOT/

RUN bundle config --global frozen 1 \
    && bundle install --without production:test:assets -j4 --retry 3 --path=vendor/bundle \
    # Remove unneeded files (cached *.gem, *.o, *.c)
    && rm -rf vendor/bundle/ruby/2.5.0/cache/*.gem \
    && find vendor/bundle/ruby/2.5.0/gems/ -name "*.c" -delete \
    && find vendor/bundle/ruby/2.5.0/gems/ -name "*.o" -delete
RUN yarn install --production

COPY . .

RUN BUILD_CONTEXT=docker SECRET_KEY_BASE=abc bundle exec rake assets:clobber assets:precompile

# Remove folders not needed in resulting image
RUN rm -rf node_modules tmp/cache app/assets vendor/assets spec
############### Build step done ###############

FROM ruby:2.5.1-alpine
ARG RAILS_ROOT=/app
ARG PACKAGES="tzdata postgresql-client nodejs bash"
ENV RAILS_ENV=development
ENV BUNDLE_APP_CONFIG="$RAILS_ROOT/.bundle"
WORKDIR $RAILS_ROOT
# install packages
RUN apk update \
    && apk upgrade \
    && apk add --update --no-cache $PACKAGES
COPY --from=build-env $RAILS_ROOT $RAILS_ROOT

COPY entrypoint.sh /usr/bin/
RUN chmod +x /usr/bin/entrypoint.sh
ENTRYPOINT ["entrypoint.sh"]

EXPOSE 3000
CMD ["bundle", "exec","rails", "server", "-b", "0.0.0.0"]
