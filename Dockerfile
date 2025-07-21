# Imagen base de Node.js
FROM node:18

# Directorio de trabajo
WORKDIR /app

# Copiamos solo los archivos necesarios primero para aprovechar cache
COPY themes/${ACTIVE_THEME}/assets/package*.json ./

# Instalamos dependencias
RUN npm install

# Copiamos todos los archivos del tema
COPY themes/${ACTIVE_THEME} /var/www/html/wp-content/themes/${ACTIVE_THEME}

# Establecemos variables de entorno
ENV NODE_ENV=development

# Exponemos el puerto de Vite (debe coincidir con .env)
EXPOSE ${VITE_PORT}

# Comando para iniciar el servidor de desarrollo
CMD ["npm", "run", "dev"]
