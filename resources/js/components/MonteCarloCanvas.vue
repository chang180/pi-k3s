<script setup lang="ts">
import { ref, watch, onMounted } from 'vue';

const props = defineProps<{
    insideCount: number;
    totalCount: number;
}>();

const canvasRef = ref<HTMLCanvasElement | null>(null);
const MAX_DRAWN_POINTS = 10000;

function draw(): void {
    const canvas = canvasRef.value;
    if (!canvas) {
        return;
    }

    const ctx = canvas.getContext('2d');
    if (!ctx) {
        return;
    }

    const size = canvas.width;
    ctx.clearRect(0, 0, size, size);

    // Draw background
    ctx.fillStyle = '#1e1e2e';
    ctx.fillRect(0, 0, size, size);

    // Draw quarter circle
    ctx.beginPath();
    ctx.arc(0, 0, size, 0, Math.PI / 2);
    ctx.lineTo(0, 0);
    ctx.closePath();
    ctx.fillStyle = 'rgba(99, 102, 241, 0.15)';
    ctx.fill();
    ctx.strokeStyle = 'rgba(99, 102, 241, 0.5)';
    ctx.lineWidth = 2;
    ctx.stroke();

    if (props.totalCount === 0) {
        return;
    }

    // Sample proportionally to MAX_DRAWN_POINTS
    const drawCount = Math.min(props.totalCount, MAX_DRAWN_POINTS);
    const insideRatio = props.insideCount / props.totalCount;
    const insideDraw = Math.round(drawCount * insideRatio);
    const outsideDraw = drawCount - insideDraw;

    // Seed random for reproducibility within a render
    const rng = mulberry32(42);

    // Draw inside points (blue)
    ctx.fillStyle = 'rgba(96, 165, 250, 0.7)';
    for (let i = 0; i < insideDraw; i++) {
        let x: number, y: number;
        do {
            x = rng();
            y = rng();
        } while (x * x + y * y > 1);
        ctx.fillRect(x * size, y * size, 2, 2);
    }

    // Draw outside points (red)
    ctx.fillStyle = 'rgba(248, 113, 113, 0.7)';
    for (let i = 0; i < outsideDraw; i++) {
        let x: number, y: number;
        do {
            x = rng();
            y = rng();
        } while (x * x + y * y <= 1);
        ctx.fillRect(x * size, y * size, 2, 2);
    }
}

function mulberry32(seed: number): () => number {
    let a = seed;
    return () => {
        a |= 0;
        a = (a + 0x6d2b79f5) | 0;
        let t = Math.imul(a ^ (a >>> 15), 1 | a);
        t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
        return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
    };
}

onMounted(() => draw());
watch(() => [props.insideCount, props.totalCount], () => draw());
</script>

<template>
    <div class="rounded-xl border border-sidebar-border/70 bg-card p-5 dark:border-sidebar-border">
        <h3 class="mb-3 text-lg font-semibold">Monte Carlo Simulation</h3>
        <div class="flex items-center justify-center">
            <canvas
                ref="canvasRef"
                width="280"
                height="280"
                class="rounded-lg"
            />
        </div>
        <div class="mt-3 flex justify-between text-xs text-muted-foreground">
            <span>
                <span class="mr-1 inline-block h-2 w-2 rounded-full bg-blue-400" />
                Inside: {{ insideCount.toLocaleString() }}
            </span>
            <span>
                <span class="mr-1 inline-block h-2 w-2 rounded-full bg-red-400" />
                Outside: {{ (totalCount - insideCount).toLocaleString() }}
            </span>
        </div>
    </div>
</template>
