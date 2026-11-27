FROM registry.access.redhat.com/ubi9/nodejs-24-minimal:latest

# Switch to root only to create and own the working directory. The base image defaults to UID 1001.
USER 0

# The app needs no extra OS packages. If one is needed later, add it here with microdnf and then clean up:
# RUN microdnf install -y <package> && microdnf clean all

# Create /app and give it to the non-root user (UID 1001, GID 0) so npm install can write to it.
RUN mkdir -p /app && chown -R 1001:0 /app

WORKDIR /app

# Copy files as the non-root user so the app does not run with root-owned files.
COPY --chown=1001:0 package.json .

# Drop privileges before installing dependencies and running the app (non-root USER).
USER 1001

RUN npm install

COPY --chown=1001:0 . .

# Port 3000 is above 1024, so a non-root user can bind to it.
EXPOSE 3000

CMD ["node", "app.js"]
