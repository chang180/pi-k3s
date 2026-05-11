<script setup lang="ts">
defineProps<{
    calculating: boolean;
    isStreaming: boolean;
}>();

const selectedPoints = defineModel<number>('selectedPoints', { required: true });
const selectedMode = defineModel<string>('selectedMode', { required: true });

const emit = defineEmits<{
    start: [];
    stop: [];
    reset: [];
}>();

const pointsOptions = [
    { value: 100000, label: '10 萬點 (100K)' },
    { value: 1000000, label: '100 萬點 (1M)' },
    { value: 10000000, label: '1000 萬點 (10M)' },
    { value: 30000000, label: '3000 萬點 (30M) — 建議觸發 HPA' },
    { value: 50000000, label: '5000 萬點 (50M) — 最大值' },
];

const modeOptions = [
    { value: 'single', label: '單機' },
    { value: 'distributed', label: '分散式' },
];
</script>

<template>
    <div class="rounded-xl border border-sidebar-border/70 bg-card p-5 dark:border-sidebar-border">
        <h3 class="mb-4 text-lg font-semibold">控制面板</h3>

        <div class="mb-4">
            <label class="mb-1.5 block text-sm font-medium">點數</label>
            <select
                v-model.number="selectedPoints"
                class="w-full rounded-lg border border-input bg-background px-3 py-2 text-sm"
                :disabled="calculating || isStreaming"
            >
                <option v-for="opt in pointsOptions" :key="opt.value" :value="opt.value">
                    {{ opt.label }}
                </option>
            </select>
        </div>

        <div class="mb-4">
            <label class="mb-1.5 block text-sm font-medium">執行模式</label>
            <div class="flex gap-2">
                <button
                    v-for="opt in modeOptions"
                    :key="opt.value"
                    type="button"
                    class="flex-1 rounded-lg border px-3 py-2 text-sm font-medium transition-colors"
                    :class="
                        selectedMode === opt.value
                            ? 'border-primary bg-primary text-primary-foreground'
                            : 'border-input bg-background hover:bg-muted'
                    "
                    :disabled="calculating || isStreaming"
                    @click="selectedMode = opt.value"
                >
                    {{ opt.label }}
                </button>
            </div>
        </div>

        <div class="flex gap-2">
            <button
                v-if="!calculating && !isStreaming"
                type="button"
                class="flex-1 rounded-lg bg-primary px-4 py-2 text-sm font-medium text-primary-foreground transition-colors hover:bg-primary/90"
                @click="emit('start')"
            >
                開始
            </button>
            <button
                v-if="calculating || isStreaming"
                type="button"
                class="flex-1 rounded-lg bg-destructive px-4 py-2 text-sm font-medium text-destructive-foreground transition-colors hover:bg-destructive/90"
                @click="emit('stop')"
            >
                停止
            </button>
            <button
                type="button"
                class="rounded-lg border border-input bg-background px-4 py-2 text-sm font-medium transition-colors hover:bg-muted"
                :disabled="calculating || isStreaming"
                @click="emit('reset')"
            >
                重置
            </button>
        </div>
    </div>
</template>
