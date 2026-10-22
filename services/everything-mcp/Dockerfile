FROM node:22-alpine
RUN npm install -g @modelcontextprotocol/server-everything@1.0.0
USER node
ENV PORT=3001
EXPOSE 3001
CMD ["mcp-server-everything", "streamableHttp"]
