const { GoogleGenerativeAI } = require('@google/generative-ai');

const genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY);
const model = genAI.getGenerativeModel({ model: 'gemini-2.5-flash' });

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

// Original bulk generation (kept for backward compat)
async function generateReelsFromText(pdfText, subject = 'General') {
  const prompt = `You are an educational content creator who makes viral, engaging study reels (like Instagram/TikTok but for learning).

Given this study material, create 5-8 short educational reels. Each reel should cover ONE key concept and be engaging for students.

Rules:
- Keep each slide short (max 2 sentences)
- Use simple language, make it fun
- Add relevant emojis
- Include a quiz at the end of each reel
- The narration should be conversational, like a friendly tutor

Subject: ${subject}

Study Material:
${pdfText.substring(0, 15000)}

Return ONLY valid JSON in this exact format:
{
  "reels": [
    {
      "title": "Short catchy title",
      "slides": [
        {
          "heading": "Slide heading",
          "content": "Brief explanation (1-2 sentences max)",
          "emoji": "relevant emoji"
        }
      ],
      "narration": "Full narration script for TTS (conversational, 30-60 seconds when spoken)",
      "quiz": {
        "question": "Quick quiz question about this concept",
        "options": ["Option A", "Option B", "Option C", "Option D"],
        "answer": 0
      },
      "tags": ["tag1", "tag2"]
    }
  ]
}`;

  try {
    const result = await model.generateContent(prompt);
    const text = result.response.text();
    return parseJsonResponse(text);
  } catch (e) {
    throw new Error(`Bulk reel generation failed: ${e.message}`);
  }
}

// Step 1: Fast concept extraction (~2s)
async function extractConcepts(pdfText, subject = 'General') {
  const prompt = `You are an educational content analyzer. Given this study material, identify 5-8 KEY concepts that would make great short educational reels.

Subject: ${subject}

Study Material:
${pdfText.substring(0, 15000)}

Return ONLY valid JSON:
{
  "concepts": [
    "Concept Title: One line description of what to teach",
    "Concept Title: One line description of what to teach"
  ]
}`;

  try {
    const result = await model.generateContent(prompt);
    const text = result.response.text();
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
async function generateSingleReel(concept, pdfText, subject = 'General') {
  const prompt = `You are an educational content creator making a viral study reel about this specific concept.

Concept: ${concept}
Subject: ${subject}

Reference material (use relevant parts):
${pdfText.substring(0, 8000)}

Create ONE educational reel with 3-5 slides. Rules:
- Keep each slide short (max 2 sentences)
- Use simple language, make it fun and engaging
- Add relevant emojis
- Include a quiz at the end
- Narration should be conversational, like a friendly tutor

Return ONLY valid JSON:
{
  "title": "Short catchy title",
  "slides": [
    { "heading": "Slide heading", "content": "Brief explanation (1-2 sentences)", "emoji": "relevant emoji" }
  ],
  "narration": "Conversational narration script (30-60 seconds when spoken)",
  "quiz": {
    "question": "Quick quiz question",
    "options": ["Option A", "Option B", "Option C", "Option D"],
    "answer": 0
  },
  "tags": ["tag1", "tag2"]
}`;

  try {
    const result = await model.generateContent(prompt);
    const text = result.response.text();
    const data = parseJsonResponse(text);
    if (!data.title || !data.slides) {
      throw new Error('AI response missing title or slides');
    }
    return data;
  } catch (e) {
    throw new Error(`Single reel generation failed: ${e.message}`);
  }
}

// Step 3: Generate an animated video reel for one concept
async function generateVideoReel(concept, pdfText, subject = 'General') {
  const prompt = `You are creating an animated educational video reel (like Instagram Stories) about this concept.

Concept: ${concept}
Subject: ${subject}

Reference material:
${pdfText.substring(0, 8000)}

Create a video reel with 4-6 scenes. Each scene appears for a few seconds with animated text and emoji. Think of it like an Instagram Story that teaches something.

Rules:
- Each scene has ONE key point (1-2 sentences max)
- Use big, expressive emojis
- Pick vibrant gradient colors that match the mood
- Transitions: use "fade", "slide", or "scale"
- Total duration should be 15-25 seconds
- Include a quiz at the end

Return ONLY valid JSON:
{
  "title": "Short catchy title",
  "scenes": [
    {
      "text": "Main point for this scene (1-2 sentences)",
      "emoji": "🔥",
      "duration": 3,
      "transition": "fade",
      "backgroundGradient": ["#667eea", "#764ba2"]
    }
  ],
  "narration": "Full narration script for the whole video",
  "quiz": {
    "question": "Quick quiz question",
    "options": ["Option A", "Option B", "Option C", "Option D"],
    "answer": 0
  },
  "tags": ["tag1", "tag2"]
}`;

  try {
    const result = await model.generateContent(prompt);
    const text = result.response.text();
    const data = parseJsonResponse(text);
    if (!data.title || !data.scenes) {
      throw new Error('AI response missing title or scenes');
    }
    return data;
  } catch (e) {
    throw new Error(`Video reel generation failed: ${e.message}`);
  }
}

module.exports = {
  generateReelsFromText,
  extractConcepts,
  generateSingleReel,
  generateVideoReel,
};
