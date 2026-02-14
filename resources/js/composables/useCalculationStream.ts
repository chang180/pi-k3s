import { ref, onUnmounted } from 'vue';
import type { StreamUpdate, PiHistoryEntry } from '@/types';

export function useCalculationStream() {
    const streamData = ref<StreamUpdate | null>(null);
    const isStreaming = ref(false);
    const piHistory = ref<PiHistoryEntry[]>([]);

    let eventSource: EventSource | null = null;
    let startTime = 0;

    function startStream(calculationId: number | string): void {
        stopStream();

        piHistory.value = [];
        streamData.value = null;
        isStreaming.value = true;
        startTime = Date.now();

        eventSource = new EventSource(`/api/calculate/${calculationId}/stream`);

        eventSource.addEventListener('update', (event: MessageEvent) => {
            if (event.data === '</stream>') {
                stopStream();
                return;
            }

            const data: StreamUpdate = JSON.parse(event.data);
            streamData.value = data;

            if (data.partial_pi > 0) {
                piHistory.value.push({
                    time: (Date.now() - startTime) / 1000,
                    pi: data.partial_pi,
                });
            }

            if (data.status === 'completed' || data.status === 'failed') {
                stopStream();
            }
        });

        eventSource.onerror = () => {
            stopStream();
        };
    }

    function stopStream(): void {
        if (eventSource) {
            eventSource.close();
            eventSource = null;
        }
        isStreaming.value = false;
    }

    onUnmounted(() => {
        stopStream();
    });

    return {
        streamData,
        isStreaming,
        piHistory,
        startStream,
        stopStream,
    };
}
