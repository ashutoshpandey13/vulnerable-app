FROM registry.access.redhat.com/ubi9/nodejs-24-minimal:latest

# Changed: switch to root only to prepare the working directory. The image default user is non-root (UID 1001).
USER 0

WORKDIR /app

# Changed: give the non-root user (UID 1001, GID 0) ownership of /app so npm install and the app can write there.
RUN chown 1001:0 /app

# Changed: drop privileges. The build steps and the app run as non-root.
USER 1001

# Changed: --chown keeps copied files owned by the non-root user.
COPY --chown=1001:0 package.json .

# Note: no extra OS packages are needed. If one is required later, add it as root
# with "microdnf install -y <pkg> && microdnf clean all" (UBI minimal uses microdnf, not apk or apt).
RUN npm install

COPY --chown=1001:0 . .

EXPOSE 3000

CMD ["node", "app.js"]
