import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
import path from 'path';

export default defineConfig(({ mode }) => {
    // Vite carga automáticamente .env y .env.[mode]
    const isDev = process.env.VITE_DEV_MODE === 'true';
    const vitePort = process.env.VITE_PORT ? parseInt(process.env.VITE_PORT, 10) : 1159;

    console.log(`VITE_DEV_MODE: ${isDev}`);
    console.log(`VITE_PORT: ${vitePort}`);

    return {
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
            host: true,              // Servidor disponible en localhost
            port: vitePort,          // Puerto configurable desde .env
            strictPort: true,        // Asegura que se utilice este puerto y no uno alternativo
            watch: {
                usePolling: true,    // Útil para sistemas de archivos montados como Docker
                interval: 100,       // Intervalo de polling en milisegundos
            },
        },
        css: {
            preprocessorOptions: {
                scss: {
                    // Variables globales SCSS
                    additionalData: `@use "./styles/abstracts/variables.scss";`,
                },
            },
        },
    };
});
