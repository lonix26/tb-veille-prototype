import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";

// Application de restitution — build statique servi par le conteneur nginx
// (docker-compose, service « dashboard »). Aucune logique serveur : le
// build produit des fichiers, l'API de restitution n8n reste la seule
// interface de lecture de la base.
export default defineConfig({
  plugins: [react()],
  base: "./",
  build: { outDir: "dist", sourcemap: false }
});
