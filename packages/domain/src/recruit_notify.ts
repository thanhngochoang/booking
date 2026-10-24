/**
 * `recruit_post_new` fan-out (plan #151 Decision 8): called once per created post (trigger). Providers whose
 * match keys meet the post's (at most 200, the studio itself dropped) each get #138's `notifyRecruitPostNew`
 * through a daily cap of 3 per VN day, checked and counted in one transaction; capped ones are skipped,
 * not queued. A replayed trigger counts and sends nothing twice (`notices.postIds` + the hook's dedupe key).
 */

import { notifyRecruitPostNew } from './notification_hooks.js';
import { RECRUIT_FANOUT_MAX, RECRUIT_NOTICES_DAILY, type NoticeDaily } from './recruit.js';
import type { RecruitDeps } from './recruit_ports.js';
import { vnDayKey } from './verification.js';

/** One more notice for `postId` today; 'counted' when this post was already counted today; 'capped' when full. */
export function takeNotice(d: NoticeDaily | null, postId: string, at: Date): NoticeDaily | 'counted' | 'capped' {
  const day = vnDayKey(at);
  if (d === null || d.day !== day) return { day, count: 1, postIds: [postId] };
  if (d.postIds.includes(postId)) return 'counted';
  if (d.count >= RECRUIT_NOTICES_DAILY) return 'capped';
  return { day, count: d.count + 1, postIds: [...d.postIds, postId] };
}

export async function notifyRecruitMatches(deps: RecruitDeps, postId: string): Promise<{ sent: number; capped: number }> {
  const post = await deps.store.runTransaction((tx) => tx.getPost(postId));
  const now = deps.clock.now();
  if (!post || post.status !== 'open' || post.expiresAt <= now) return { sent: 0, capped: 0 };

  const recipients = (await deps.store.matchingProviders(post.matchKeys, RECRUIT_FANOUT_MAX))
    .filter((uid) => uid !== post.studioId);
  let sent = 0;
  let capped = 0;
  for (const uid of recipients) {
    const taken = await deps.store.runTransaction(async (tx) => {
      const c = await tx.getCounters(uid);
      const next = takeNotice(c.notices, post.id, now);
      if (typeof next !== 'string') tx.putCounters(uid, { ...c, notices: next });
      return next;
    });
    if (taken === 'capped') {
      capped += 1;
      continue;
    }
    try {
      const result = await notifyRecruitPostNew(deps.notify, { recipientId: uid, studioId: post.studioId, postId: post.id, title: post.title });
      if (result === 'created' || result === 'grouped') sent += 1;
    } catch (e) {
      deps.notify.onPushError?.(uid, e);
    }
  }
  return { sent, capped };
}
