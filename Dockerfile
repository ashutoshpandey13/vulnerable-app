FROM registry.access.redhat.com/ubi9/nodejs-24-minimal:latest

# Changed: switch to root only to prepare the app directory. The image defaults to UID 1001.
USER 0

WORKDIR /app

# Changed: give the app directory to the non-root user so npm install can write to it.
# No extra OS packages are needed. If the app needs any, install them here with
# "microdnf install -y <pkg> && microdnf clean all" (microdnf, not apk or apt).
RUN chown -R 1001:0 /app && chmod -R g=u /app

# Changed: drop privileges. Everything below, including the running app, uses a non-root user.
USER 1001

# Changed: --chown keeps the copied files owned by the non-root user.
COPY --chown=1001:0 package.json .

RUN npm install

COPY --chown=1001:0 . .

EXPOSE 3000

CMD ["node", "app.js"]
