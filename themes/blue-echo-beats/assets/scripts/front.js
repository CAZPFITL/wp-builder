import 'normalize.css';
// import './../styles/front.scss'

console.log('front')

import '../styles/front.scss';

// Esperar a que el DOM esté listo
document.addEventListener('DOMContentLoaded', () => {
    const canvas = document.getElementById('starfield');
    if (!canvas) return; // Si no existe el canvas, no ejecutar

    const ctx = canvas.getContext('2d');
    let stars = [];
    const numStars = 1000;
    let width, height, centerX, centerY;
    let speedFactor = 2;
    const farStartProbability = 0.75;
    const farStarRange = [0.001, 0.25];
    const closeStarRange = [1, 5];

    function resizeCanvas() {
        width = window.innerWidth;
        height = window.innerHeight;
        canvas.width = width;
        canvas.height = height;
        centerX = width / 2;
        centerY = height / 2;
    }

    function randomCentered(scale) {
        const value = Math.random() - 0.5;
        return value * scale * (1 + Math.random() * 0.3);
    }

    function calculateSpeed() {
        const rand = Math.random();
        const [minSpeed, maxSpeed] = rand < farStartProbability ? farStarRange : closeStarRange;
        return minSpeed + Math.random() * (maxSpeed - minSpeed);
    }

    function calculateSize(star) {
        const proximityFactor = star.speed / 8;
        let baseSize = Math.max(0.5, (0.5 - star.z / width) * 5);
        if (proximityFactor > 0.5) {
            baseSize *= (1 + (width - star.z) / width * proximityFactor);
        }
        return Math.max(baseSize, 0.5);
    }

    function createStars() {
        stars = [];
        for (let i = 0; i < numStars; i++) {
            const star = {
                x: randomCentered(width),
                y: randomCentered(height),
                z: Math.random() * width / 2,
                size: 0, // se recalcula al volar
                speed: calculateSpeed()
            };
            star.size = calculateSize(star);
            stars.push(star);
        }
    }

    function updateStars() {
        for (let i = 0; i < numStars; i++) {
            const star = stars[i];
            star.z -= star.speed * speedFactor;
            if (star.z <= 0) {
                star.x = randomCentered(width);
                star.y = randomCentered(height);
                star.z = Math.random() * width / 2;
                star.speed = calculateSpeed();
                star.size = calculateSize(star);
            }
            const k = 128.0 / star.z;
            const sx = star.x * k + centerX;
            const sy = star.y * k + centerY;
            if (sx >= 0 && sx < width && sy >= 0 && sy < height) {
                ctx.beginPath();
                ctx.arc(sx, sy, calculateSize(star) / 2, 0, Math.PI * 2);
                ctx.fillStyle = 'white';
                ctx.fill();
            }
        }
    }

    function animate() {
        ctx.fillStyle = 'black';
        ctx.fillRect(0, 0, width, height);
        updateStars();
        requestAnimationFrame(animate);
    }

    window.addEventListener('resize', () => {
        resizeCanvas();
        createStars();
    });

    resizeCanvas();
    createStars();
    animate();
});
