/** @type {import('tailwindcss').Config} */
module.exports = {
  content: ['./app/**/*.{js,jsx,ts,tsx}', './src/**/*.{js,jsx,ts,tsx}'],
  presets: [require('nativewind/preset')],
  theme: {
    extend: {
      // Placeholder palette until the owner supplies a logo (PLAN §9).
      colors: {
        primary: '#B4441C',
        accent: '#F2B134',
        ink: '#2B1A12',
        cream: '#FFF8F1',
      },
    },
  },
  plugins: [],
};
