<script setup lang="ts">
import { computed } from 'vue';
import { Line } from 'vue-chartjs';
import {
    Chart as ChartJS,
    CategoryScale,
    LinearScale,
    PointElement,
    LineElement,
    Title,
    Tooltip,
    Legend,
    Filler,
} from 'chart.js';
import type { PiHistoryEntry } from '@/types';

ChartJS.register(CategoryScale, LinearScale, PointElement, LineElement, Title, Tooltip, Legend, Filler);

const props = defineProps<{
    piHistory: PiHistoryEntry[];
}>();

const chartData = computed(() => ({
    labels: props.piHistory.map((e) => `${e.time.toFixed(1)}s`),
    datasets: [
        {
            label: 'Calculated π',
            data: props.piHistory.map((e) => e.pi),
            borderColor: 'rgb(99, 102, 241)',
            backgroundColor: 'rgba(99, 102, 241, 0.1)',
            fill: false,
            tension: 0.3,
            pointRadius: 2,
        },
        {
            label: 'Actual π',
            data: props.piHistory.map(() => Math.PI),
            borderColor: 'rgba(248, 113, 113, 0.7)',
            borderDash: [5, 5],
            fill: false,
            pointRadius: 0,
        },
    ],
}));

const chartOptions = {
    responsive: true,
    maintainAspectRatio: false,
    plugins: {
        legend: {
            labels: {
                color: '#9ca3af',
            },
        },
    },
    scales: {
        x: {
            ticks: { color: '#9ca3af' },
            grid: { color: 'rgba(107, 114, 128, 0.2)' },
        },
        y: {
            ticks: { color: '#9ca3af' },
            grid: { color: 'rgba(107, 114, 128, 0.2)' },
            suggestedMin: 3.0,
            suggestedMax: 3.3,
        },
    },
};
</script>

<template>
    <div class="rounded-xl border border-sidebar-border/70 bg-card p-5 dark:border-sidebar-border">
        <h3 class="mb-3 text-lg font-semibold">π Convergence</h3>
        <div class="h-64">
            <Line :data="chartData" :options="chartOptions" />
        </div>
    </div>
</template>
