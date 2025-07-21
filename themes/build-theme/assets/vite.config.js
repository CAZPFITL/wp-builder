import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
import path from 'path';

export default defineConfig({
    plugins: [react()],
    build: {
        rollupOptions: {
            input: {
                front: './scripts/front.js',
                admin: './scripts/admin.js',
                'styles/front': './styles/front.scss', // Entrada SCSS como independiente
                'styles/admin': './styles/admin.scss', // Entrada SCSS como independiente
            },
            output: {
                entryFileNames: 'scripts/[name].js',
                assetFileNames: 'styles/[name].[ext]',
            },
        },
        manifest: true, // Generar manifest.json
    },
    server: {
        host: true, // Servidor disponible en localhost
        port: 5173, // Puerto para el servidor de desarrollo
        strictPort: true, // Asegura que se utilice este puerto y no uno alternativo
        watch: {
            usePolling: true, // Útil para sistemas de archivos montados como Docker
            interval: 100, // Intervalo de polling en milisegundos
        },
    },
    css: {
        preprocessorOptions: {
            scss: {
                // Opcional: Agregar variables globales o mixins
                additionalData: `@import "./styles/abstracts/variables.scss";`,
            },
        },
    },
});
