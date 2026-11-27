FROM registry.access.redhat.com/ubi9/nodejs-24-minimal:latest

# Switch to root only to create /app and give it to the unprivileged user.
# The app needs no extra OS packages. If one is needed later, add:
#   RUN microdnf install -y <package> && microdnf clean all
USER 0

WORKDIR /app

# Make /app writable for the non-root user (UID 1001) so npm install works.
RUN chown -R 1001:0 /app && chmod -R g=u /app

# Run all remaining steps and the application as a non-root user.
USER 1001

# Copy the manifest with the right ownership.
COPY --chown=1001:0 package.json .

RUN npm install

# Copy application source with the right ownership.
COPY --chown=1001:0 . .

EXPOSE 3000

CMD ["node", "app.js"]
