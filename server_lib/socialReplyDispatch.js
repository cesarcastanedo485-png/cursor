function env(name) {
  return String(process.env[name] || "").trim();
}

async function postJson(url, body, { headers = {}, timeoutMs = 15000 } = {}) {
  const ctl = new AbortController();
  const timer = setTimeout(() => ctl.abort(), timeoutMs);
  try {
    const res = await fetch(url, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Accept: "application/json",
        ...headers,
      },
      body: JSON.stringify(body || {}),
      signal: ctl.signal,
    });
    let data = null;
    try {
      data = await res.json();
    } catch (_) {}
    if (!res.ok) {
      const msg = data?.error?.message || data?.error || data?.message || `HTTP ${res.status}`;
      throw new Error(msg);
    }
    return data || {};
  } finally {
    clearTimeout(timer);
  }
}

async function postWebhook(url, payload) {
  const data = await postJson(url, payload, {});
  return {
    provider: "webhook",
    status: "sent",
    remoteId: data?.id || data?.messageId || null,
  };
}

async function dispatchMetaReply({ event, replyText }) {
  const payload = event.payload || {};
  const token = String(payload.pageAccessToken || env("MORDECAI_META_PAGE_ACCESS_TOKEN")).trim();
  if (!token) {
    const webhook = env("MORDECAI_META_REPLY_WEBHOOK");
    if (webhook) return postWebhook(webhook, { event, replyText });
    throw new Error("Meta token missing (set MORDECAI_META_PAGE_ACCESS_TOKEN)");
  }

  if (event.eventType === "comment_received") {
    const parentCommentId = String(payload.commentId || payload.parentCommentId || "").trim();
    if (!parentCommentId) throw new Error("Meta commentId missing");
    const data = await postJson(
      `https://graph.facebook.com/v22.0/${encodeURIComponent(parentCommentId)}/comments?access_token=${encodeURIComponent(token)}`,
      { message: replyText }
    );
    return { provider: "meta_graph", status: "sent", remoteId: data?.id || null };
  }

  const pageId = String(payload.pageId || env("MORDECAI_META_PAGE_ID")).trim();
  const recipientId = String(payload.recipientId || payload.senderId || payload.userId || "").trim();
  if (!pageId || !recipientId) {
    throw new Error("Meta DM payload missing pageId or recipientId");
  }
  const data = await postJson(
    `https://graph.facebook.com/v22.0/${encodeURIComponent(pageId)}/messages?access_token=${encodeURIComponent(token)}`,
    {
      messaging_type: "RESPONSE",
      recipient: { id: recipientId },
      message: { text: replyText },
    }
  );
  return { provider: "meta_graph", status: "sent", remoteId: data?.message_id || null };
}

async function dispatchYoutubeReply({ event, replyText }) {
  const payload = event.payload || {};
  const token = String(payload.accessToken || env("MORDECAI_YOUTUBE_ACCESS_TOKEN")).trim();
  if (!token) {
    const webhook = env("MORDECAI_YOUTUBE_REPLY_WEBHOOK");
    if (webhook) return postWebhook(webhook, { event, replyText });
    throw new Error("YouTube token missing (set MORDECAI_YOUTUBE_ACCESS_TOKEN)");
  }
  const parentCommentId = String(payload.commentId || payload.parentCommentId || "").trim();
  if (!parentCommentId) {
    throw new Error("YouTube commentId missing for reply");
  }
  const data = await postJson(
    "https://www.googleapis.com/youtube/v3/comments?part=snippet",
    {
      snippet: {
        parentId: parentCommentId,
        textOriginal: replyText,
      },
    },
    {
      headers: { Authorization: `Bearer ${token}` },
    }
  );
  return { provider: "youtube_api", status: "sent", remoteId: data?.id || null };
}

async function dispatchTikTokReply({ event, replyText }) {
  const webhook = String(event.payload?.replyWebhook || env("MORDECAI_TIKTOK_REPLY_WEBHOOK")).trim();
  if (!webhook) {
    throw new Error("TikTok reply webhook missing (set MORDECAI_TIKTOK_REPLY_WEBHOOK)");
  }
  return postWebhook(webhook, { event, replyText });
}

export async function dispatchAutoReply({ event, replyText }) {
  const platform = String(event.platform || "").trim().toLowerCase();
  if (platform === "facebook" || platform === "messenger") {
    return dispatchMetaReply({ event, replyText });
  }
  if (platform === "youtube") {
    return dispatchYoutubeReply({ event, replyText });
  }
  if (platform === "tiktok") {
    return dispatchTikTokReply({ event, replyText });
  }
  const fallbackWebhook = env("MORDECAI_SOCIAL_REPLY_WEBHOOK");
  if (!fallbackWebhook) {
    throw new Error(`Unsupported platform for auto-reply: ${platform || "unknown"}`);
  }
  return postWebhook(fallbackWebhook, { event, replyText });
}
