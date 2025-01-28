<script setup>
import { ref, watch } from 'vue';

const props = defineProps({
    imageUrl: {
        type: String,
        required: true
    },
    show: {
        type: Boolean,
        default: false
    }
});

const emit = defineEmits(['close-image-detail']);

const positivePrompt = ref('');
const negativePrompt = ref('');
const errorMessage = ref('');

watch(() => props.imageUrl, async (newUrl) => {
    if (newUrl) {
        await parseImage(newUrl);
    }
}, { immediate: true });

async function parseImage(url) {
    try {
        const response = await fetch(url);
        const blob = await response.blob();
        const text = await blob.text();

        const positiveMatch = text.match(/HtEXparameters:([\s\S]*?)Negative prompt:/);
        const negativeMatch = text.match(/Negative prompt:([\s\S]*?)Steps:/);

        if (positiveMatch && negativeMatch) {
            positivePrompt.value = positiveMatch[1].trim();
            negativePrompt.value = negativeMatch[1].trim();
        } else {
            const positiveJsonMatch = text.match(/"positive":\s*"([^"]*)"/);
            const negativeJsonMatch = text.match(/"negative":\s*"([^"]*)"/);

            if (positiveJsonMatch && negativeJsonMatch) {
                positivePrompt.value = positiveJsonMatch[1].trim();
                negativePrompt.value = negativeJsonMatch[1].trim();
            } else {
                errorMessage.value = '无法解析图片中的提示信息';
            }
        }
    } catch (error) {
        errorMessage.value = '解析图片失败';
        console.error('Error parsing image:', error);
    }
}

function handleClose() {
    emit('close-image-detail');
}

function handleOverlayClick(e) {
    if (e.target.classList.contains('image-overlay')) {
        emit('close-image-detail');
    }
}
</script>

<template>
    <Transition name="fade">
        <div v-if="show" class="overlay image-overlay" @click="handleOverlayClick">
            <div class="detail-card" @click.stop>
                <button class="close-btn" @click="handleClose">×</button>
                <div class="content-wrapper">
                    <div v-if="errorMessage" class="error-message">{{ errorMessage }}</div>
                    <div v-else>
                        <h2>Positive Prompt</h2>
                        <textarea v-model="positivePrompt" readonly></textarea>
                        <h2>Negative Prompt</h2>
                        <textarea v-model="negativePrompt" readonly></textarea>
                    </div>
                </div>
            </div>
        </div>
    </Transition>
</template>

<style scoped>
.overlay {
    position: fixed;
    top: 0;
    left: 0;
    right: 0;
    bottom: 0;
    background: rgba(0, 0, 0, 0.5);
    display: flex;
    align-items: center;
    justify-content: center;
    z-index: 1000;
}

.detail-card {
    background: white;
    border-radius: 12px;
    width: 90%;
    max-width: 800px;
    max-height: 90vh;
    overflow-y: auto;
    position: relative;
    padding: 2rem;
    box-shadow: 0 8px 16px rgba(0, 0, 0, 0.2);
}

.close-btn {
    position: absolute;
    top: 1rem;
    right: 1rem;
    background: none;
    border: none;
    font-size: 1.5rem;
    cursor: pointer;
    color: #666;
    padding: 0.5rem;
    line-height: 1;
}

.content-wrapper {
    display: flex;
    flex-direction: column;
    gap: 1rem;
}

textarea {
    width: 100%;
    height: 150px;
    padding: 1rem;
    border: 1px solid #ddd;
    border-radius: 8px;
    resize: none;
    font-size: 1rem;
    background: #f8f9fa;
}

.error-message {
    color: #dc3545;
    padding: 1rem;
    background: #fee;
    border-radius: 8px;
    text-align: center;
}
</style>
