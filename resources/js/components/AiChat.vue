<script setup lang="ts">
import { ref, nextTick } from 'vue';

const input = ref('');
const messages = ref<Array<{ role: 'user' | 'assistant'; content: string }>>([]);
const isLoading = ref(false);
const chatContainer = ref<HTMLElement | null>(null);

const suggestions = [
    '蒙地卡羅法是什麼？',
    'HPA 如何自動擴展？',
    'Single 和 Distributed 模式有什麼差別？',
];

async function sendMessage(text?: string): Promise<void> {
    const message = text ?? input.value.trim();
    if (!message || isLoading.value) {
        return;
    }

    input.value = '';
    messages.value.push({ role: 'user', content: message });
    messages.value.push({ role: 'assistant', content: '' });
    isLoading.value = true;

    await nextTick();
    scrollToBottom();

    try {
        const response = await fetch('/api/ai/ask', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                Accept: 'text/event-stream',
            },
            body: JSON.stringify({ message }),
        });

        if (!response.ok) {
            const data = await response.json();
            messages.value[messages.value.length - 1].content =
                data.message || 'Error occurred';
            isLoading.value = false;
            return;
        }

        const reader = response.body?.getReader();
        const decoder = new TextDecoder();

        if (!reader) {
            messages.value[messages.value.length - 1].content = 'Stream unavailable';
            isLoading.value = false;
            return;
        }

        while (true) {
            const { done, value } = await reader.read();
            if (done) {
                break;
            }

            const chunk = decoder.decode(value, { stream: true });
            const lines = chunk.split('\n');

            for (const line of lines) {
                if (line.startsWith('data: ')) {
                    const data = line.slice(6);
                    if (data === '</stream>') {
                        continue;
                    }
                    messages.value[messages.value.length - 1].content += data;
                    await nextTick();
                    scrollToBottom();
                }
            }
        }
    } catch (e) {
        messages.value[messages.value.length - 1].content =
            e instanceof Error ? e.message : 'Network error';
    } finally {
        isLoading.value = false;
    }
}

function scrollToBottom(): void {
    if (chatContainer.value) {
        chatContainer.value.scrollTop = chatContainer.value.scrollHeight;
    }
}
</script>

<template>
    <div class="rounded-xl border border-sidebar-border/70 bg-card p-5 dark:border-sidebar-border">
        <h3 class="mb-3 text-lg font-semibold">Ask Pi-K3s AI</h3>

        <!-- Chat Messages -->
        <div
            ref="chatContainer"
            class="mb-3 h-64 space-y-3 overflow-y-auto rounded-lg bg-muted p-3"
        >
            <div v-if="messages.length === 0" class="flex h-full flex-col items-center justify-center gap-3">
                <p class="text-sm text-muted-foreground">Ask me about Pi-K3s!</p>
                <div class="flex flex-wrap justify-center gap-2">
                    <button
                        v-for="s in suggestions"
                        :key="s"
                        type="button"
                        class="rounded-full border border-input bg-background px-3 py-1 text-xs transition-colors hover:bg-primary hover:text-primary-foreground"
                        @click="sendMessage(s)"
                    >
                        {{ s }}
                    </button>
                </div>
            </div>

            <div
                v-for="(msg, i) in messages"
                :key="i"
                class="text-sm"
                :class="msg.role === 'user' ? 'text-right' : 'text-left'"
            >
                <div
                    class="inline-block max-w-[85%] rounded-lg px-3 py-2"
                    :class="
                        msg.role === 'user'
                            ? 'bg-primary text-primary-foreground'
                            : 'bg-background'
                    "
                >
                    <span class="whitespace-pre-wrap">{{ msg.content }}</span>
                    <span
                        v-if="msg.role === 'assistant' && msg.content === '' && isLoading"
                        class="inline-block h-4 w-4 animate-pulse rounded-full bg-muted-foreground/50"
                    />
                </div>
            </div>
        </div>

        <!-- Input -->
        <div class="flex gap-2">
            <input
                v-model="input"
                type="text"
                placeholder="Ask a question..."
                class="flex-1 rounded-lg border border-input bg-background px-3 py-2 text-sm"
                :disabled="isLoading"
                @keyup.enter="sendMessage()"
            />
            <button
                type="button"
                class="rounded-lg bg-primary px-4 py-2 text-sm font-medium text-primary-foreground transition-colors hover:bg-primary/90 disabled:opacity-50"
                :disabled="isLoading || !input.trim()"
                @click="sendMessage()"
            >
                Send
            </button>
        </div>

        <p class="mt-2 text-xs text-muted-foreground">
            Powered by OpenAI. Requires OPENAI_API_KEY.
        </p>
    </div>
</template>
