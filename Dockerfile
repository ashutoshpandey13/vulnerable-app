FROM registry.access.redhat.com/ubi9/nodejs-24-minimal:latest

# The minimal image has no build toolchain or extra OS packages, which shrinks the attack surface.
# If the app needs OS packages, install them with microdnf (not apk or apt), as root, then clean up:
# USER 0
# RUN microdnf install -y <package> && microdnf clean all && rm -rf /var/cache/yum
USER 0

WORKDIR /app

# Give the non-root user (UID 1001, group 0) ownership of /app so npm install can write to it.
RUN chown -R 1001:0 /app && chmod -R g=u /app

# Security: drop root privileges. All later steps and the running app use UID 1001.
USER 1001

# Copy with correct ownership for the non-root user.
COPY --chown=1001:0 package.json .

RUN npm install

COPY --chown=1001:0 . .

EXPOSE 3000

CMD ["node", "app.js"]
