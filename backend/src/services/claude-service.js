const Groq = require('groq-sdk');

const groq = new Groq({ apiKey: process.env.GROQ_API_KEY });
const MODEL = 'llama-3.3-70b-versatile';

const STYLE_PRESETS = {
  realistic: 'photorealistic, high detail, natural lighting, cinematic',
  anime: 'anime style, vibrant colors, Studio Ghibli inspired, detailed illustration',
  watercolor: 'watercolor painting, soft edges, artistic, pastel tones, flowing',
  '3d': '3D rendered, Pixar-style, glossy, vibrant, soft lighting',
  comic: 'comic book illustration, bold outlines, halftone dots, dynamic',
  minimalist: 'minimalist flat design, clean geometric shapes, muted palette',
  scifi: 'sci-fi digital art, neon glow, futuristic, cyberpunk aesthetic',
};

async function chatComplete(prompt) {
  const response = await groq.chat.completions.create({
    model: MODEL,
    messages: [{ role: 'user', content: prompt }],
    temperature: 0.7,
    max_tokens: 4096,
    response_format: { type: 'json_object' },
  });
  return response.choices[0].message.content;
}

function parseJsonResponse(text) {
  try {
    let jsonStr = text;
    const jsonMatch = text.match(/```(?:json)?\s*([\s\S]*?)```/);
    if (jsonMatch) jsonStr = jsonMatch[1];
    return JSON.parse(jsonStr.trim());
  } catch (e) {
    throw new Error(`Failed to parse AI response as JSON: ${e.message}`);
  }
}

function getStyleDesc(style) {
  return STYLE_PRESETS[style] || STYLE_PRESETS.realistic;
}

// Step 1: Fast concept extraction
async function extractConcepts(pdfText, subject = 'General', explanationStyle = '') {
  const styleInstruction = explanationStyle
    ? `\nIMPORTANT EXPLANATION STYLE: The user wants content explained in this specific way: "${explanationStyle}". Adapt your language, analogies, and examples to match this style throughout all slides and narration.\n`
    : '';
  const prompt = `You are an educational content analyzer. Given this study material, identify 5-8 KEY concepts that would make great short educational reels.

Subject: ${subject}

Study Material:
${pdfText.substring(0, 12000)}
${styleInstruction}
Return ONLY valid JSON:
{
  "concepts": [
    "Concept Title: One line description of what to teach",
    "Concept Title: One line description of what to teach"
  ]
}`;

  try {
    const text = await chatComplete(prompt);
    const data = parseJsonResponse(text);
    if (!data.concepts || !Array.isArray(data.concepts)) {
      throw new Error('AI response missing concepts array');
    }
    return data.concepts;
  } catch (e) {
    throw new Error(`Concept extraction failed: ${e.message}`);
  }
}

// Step 2: Generate a single card reel for one concept
async function generateSingleReel(concept, pdfText, subject = 'General', style = 'realistic', explanationStyle = '') {
  const styleDesc = getStyleDesc(style);
  const styleInstruction = explanationStyle
    ? `\nIMPORTANT EXPLANATION STYLE: The user wants content explained in this specific way: "${explanationStyle}". Adapt your language, analogies, and examples to match this style throughout all slides and narration.\n`
    : '';
  const prompt = `You are an educational content creator making a viral study reel about this specific concept.

Concept: ${concept}
Subject: ${subject}

Reference material (use relevant parts):
${pdfText.substring(0, 6000)}

Create ONE educational reel with 3-5 slides. Rules:
- Keep each slide short (max 2 sentences)
- Use simple language, make it fun and engaging
- Add relevant emojis
- Include a quiz at the end with an explanation of the correct answer
- Narration should be conversational, like a friendly tutor
- For EACH slide, generate an "imagePrompt": a detailed visual description (30-60 words) for an AI image generator to create a stunning background. Style: ${styleDesc}. Do NOT include any text, letters, numbers or words in the image description - describe only visual scenes, objects, and atmosphere that relate to the slide content.
${styleInstruction}
Return ONLY valid JSON:
{
  "title": "Short catchy title",
  "slides": [
    { "heading": "Slide heading", "content": "Brief explanation (1-2 sentences)", "emoji": "relevant emoji", "imagePrompt": "detailed visual scene description for AI image generation, ${styleDesc}" }
  ],
  "narration": "Conversational narration script (30-60 seconds when spoken)",
  "quiz": {
    "question": "Quick quiz question",
    "options": ["Option A", "Option B", "Option C", "Option D"],
    "answer": 0,
    "explanation": "Brief explanation of why the correct answer is right (1-2 sentences)"
  },
  "tags": ["tag1", "tag2"]
}`;

  try {
    const text = await chatComplete(prompt);
    const data = parseJsonResponse(text);
    if (!data.title || !data.slides) {
      throw new Error('AI response missing title or slides');
    }
    // Ensure every slide has an imagePrompt
    if (data.slides) {
      data.slides.forEach(slide => {
        if (!slide.imagePrompt || !slide.imagePrompt.trim()) {
          slide.imagePrompt = `Educational illustration about ${slide.heading || concept}, ${styleDesc}`;
        }
      });
    }
    return data;
  } catch (e) {
    throw new Error(`Single reel generation failed: ${e.message}`);
  }
}

// Step 3: Generate an animated video reel for one concept
async function generateVideoReel(concept, pdfText, subject = 'General', style = 'realistic', explanationStyle = '') {
  const styleDesc = getStyleDesc(style);
  const styleInstruction = explanationStyle
    ? `\nIMPORTANT EXPLANATION STYLE: The user wants content explained in this specific way: "${explanationStyle}". Adapt your language, analogies, and examples to match this style throughout all slides and narration.\n`
    : '';
  const prompt = `You are creating an animated educational video reel (like Instagram Stories) about this concept.

Concept: ${concept}
Subject: ${subject}

Reference material:
${pdfText.substring(0, 6000)}

Create a video reel with 4-6 scenes. Each scene appears for a few seconds with animated text and emoji.

Rules:
- Each scene has ONE key point (1-2 sentences max)
- Use big, expressive emojis
- Pick vibrant gradient colors that match the mood
- Transitions: use "fade", "slide", or "scale"
- Total duration should be 15-25 seconds
- Include a quiz at the end with an explanation
- For EACH scene, generate an "imagePrompt": a detailed visual description (30-60 words) for an AI image generator. Style: ${styleDesc}. Do NOT include text, letters, numbers or words - describe only visual scenes, objects, lighting, and atmosphere.
${styleInstruction}
Return ONLY valid JSON:
{
  "title": "Short catchy title",
  "scenes": [
    {
      "text": "Main point for this scene (1-2 sentences)",
      "emoji": "relevant emoji",
      "duration": 3,
      "transition": "fade",
      "backgroundGradient": ["#667eea", "#764ba2"],
      "imagePrompt": "detailed visual scene description for AI image generation, ${styleDesc}"
    }
  ],
  "narration": "Full narration script for the whole video",
  "quiz": {
    "question": "Quick quiz question",
    "options": ["Option A", "Option B", "Option C", "Option D"],
    "answer": 0,
    "explanation": "Brief explanation of why the correct answer is right"
  },
  "tags": ["tag1", "tag2"]
}`;

  try {
    const text = await chatComplete(prompt);
    const data = parseJsonResponse(text);
    if (!data.title || !data.scenes) {
      throw new Error('AI response missing title or scenes');
    }
    // Ensure every scene has an imagePrompt
    if (data.scenes) {
      data.scenes.forEach(scene => {
        if (!scene.imagePrompt || !scene.imagePrompt.trim()) {
          scene.imagePrompt = `Educational illustration about ${scene.text || concept}, ${styleDesc}`;
        }
      });
    }
    return data;
  } catch (e) {
    throw new Error(`Video reel generation failed: ${e.message}`);
  }
}

// Bulk generation (kept for backward compat)
async function generateReelsFromText(pdfText, subject = 'General', style = 'realistic', explanationStyle = '') {
  const styleDesc = getStyleDesc(style);
  const styleInstruction = explanationStyle
    ? `\nIMPORTANT EXPLANATION STYLE: The user wants content explained in this specific way: "${explanationStyle}". Adapt your language, analogies, and examples to match this style throughout all slides and narration.\n`
    : '';
  const prompt = `You are an educational content creator who makes viral, engaging study reels.

Given this study material, create 5-8 short educational reels. Each reel should cover ONE key concept.

Rules:
- Keep each slide short (max 2 sentences)
- Use simple language, make it fun
- Add relevant emojis
- Include a quiz at the end of each reel with an explanation
- The narration should be conversational, like a friendly tutor
- For EACH slide, generate an "imagePrompt": a detailed visual description (30-60 words) for an AI image generator. Style: ${styleDesc}. NO text/letters/numbers in the image - only visual scenes.

Subject: ${subject}

Study Material:
${pdfText.substring(0, 12000)}
${styleInstruction}
Return ONLY valid JSON in this exact format:
{
  "reels": [
    {
      "title": "Short catchy title",
      "slides": [
        {
          "heading": "Slide heading",
          "content": "Brief explanation (1-2 sentences max)",
          "emoji": "relevant emoji",
          "imagePrompt": "detailed visual description, ${styleDesc}"
        }
      ],
      "narration": "Full narration script for TTS (conversational, 30-60 seconds when spoken)",
      "quiz": {
        "question": "Quick quiz question about this concept",
        "options": ["Option A", "Option B", "Option C", "Option D"],
        "answer": 0,
        "explanation": "Brief explanation of the correct answer"
      },
      "tags": ["tag1", "tag2"]
    }
  ]
}`;

  try {
    const text = await chatComplete(prompt);
    return parseJsonResponse(text);
  } catch (e) {
    throw new Error(`Bulk reel generation failed: ${e.message}`);
  }
}

module.exports = {
  generateReelsFromText,
  extractConcepts,
  generateSingleReel,
  generateVideoReel,
  STYLE_PRESETS,
};
