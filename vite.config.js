import { defineConfig } from "vite";
import glsl from "vite-plugin-string";

export default defineConfig({
  base: "/blob-render",
  plugins: [glsl()],
});
