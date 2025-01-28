<script setup>
import { ref, watch } from 'vue';

const props = defineProps({
    imagePath: {
        type: String,
        required: true
    },
    show: {
        type: Boolean,
        default: false
    }
});

const emit = defineEmits(['close']);
const positivePrompt = ref('');
const negativePrompt = ref('');

watch(() => props.show, (newVal) => {
    if (newVal) {
        fetchImageDetails();
    }
});

function closeImageDetail() {
    emit('close');
    positivePrompt.value = '';
    negativePrompt.value = '';
}

async function fetchImageDetails() {
    try {
        const response = await fetch(props.imagePath);
        const blob = await response.blob();
        const metadata = await extractMetadata(blob);
        parsePrompts(metadata);
    } catch (error) {
        console.error('获取图片详情失败:', error);
        alert('获取图片详情失败');
    }
}

async function extractMetadata(blob) {
    return new Promise((resolve, reject) => {
        const reader = new FileReader();
        reader.onload = () => {
            const text = reader.result;
            const match = text.match(/<HtEXparameters>([\s\S]*?)<\/HtEXparameters>/);
            if (match) {
                resolve(match[1]);
            } else {
                // 备选检查
                const positiveMatch = text.match(/"positive":\s*"(.*?)"/);
                const negativeMatch = text.match(/"negative":\s*"(.*?)"/);
                if (positiveMatch || negativeMatch) {
                    resolve(text);
                } else {
                    reject('未找到 HtEXparameters 或提示词');
                }
            }
        };
        reader.onerror = reject;
        reader.readAsText(blob);
    });
}

function parsePrompts(metadata) {
    const positiveMatch = metadata.match(/(Positive prompt:|positive":)([\s\S]*?)(Negative prompt:|negative":|Steps:)/);
    const negativeMatch = metadata.match(/(Negative prompt:|negative":)([\s\S]*?)(Steps:|$)/);

    if (positiveMatch && negativeMatch) {
        positivePrompt.value = positiveMatch[2].trim();
        negativePrompt.value = negativeMatch[2].trim();
    } else {
        // 再次检查 JSON 风格
        const positiveJson = metadata.match(/"positive":\s*"(.*?)"/);
        const negativeJson = metadata.match(/"negative":\s*"(.*?)"/);
        if (positiveJson && negativeJson) {
            positivePrompt.value = positiveJson[1].trim();
            negativePrompt.value = negativeJson[1].trim();
        } else {
            alert('未找到正向或负向提示词');
        }
    }
}
</script>

<template>
    <Transition name="fade">
        <div v-if="show" class="image-detail-overlay" @click="closeImageDetail">
            <div class="image-detail-card" @click.stop>
                <button class="close-btn" @click="closeImageDetail">×</button>
                <div class="prompts">
                    <div class="prompt-section">
                        <h3>Positive Prompt</h3>
                        <textarea v-model="positivePrompt" readonly></textarea>
                    </div>
                    <div class="prompt-section">
                        <h3>Negative Prompt</h3>
                        <textarea v-model="negativePrompt" readonly></textarea>
                    </div>
                </div>
            </div>
        </div>
    </Transition>
</template>

<style scoped>
.fade-enter-active,
.fade-leave-active {
    transition: opacity 0.3s ease;
}

.fade-enter-from,
.fade-leave-to {
    opacity: 0;
}

.image-detail-overlay {
    position: fixed;
    top: 0;
    left: 0;
    right: 0;
    bottom: 0;
    background: rgba(0, 0, 0, 0.5);
    display: flex;
    align-items: center;
    justify-content: center;
    z-index: 1100;
}

.image-detail-card {
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

.prompts {
    display: flex;
    flex-direction: column;
    gap: 1.5rem;
}

.prompt-section {
    display: flex;
    flex-direction: column;
    gap: 0.5rem;
}

.prompt-section h3 {
    margin: 0;
    font-size: 1.2rem;
    color: #333;
}

.prompt-section textarea {
    width: 100%;
    height: 150px;
    padding: 0.8rem;
    border: 1px solid #ddd;
    border-radius: 4px;
    font-size: 0.9rem;
    background: #f8f9fa;
    resize: none;
    outline: none;
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
</style>
