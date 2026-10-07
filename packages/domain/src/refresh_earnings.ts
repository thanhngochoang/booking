/** Recomputes the named earning rows of one payee and their totals in one transaction. */

import { earningItemOf, summarizeEarnings, type EarningItem, type EarningsSummary } from './earnings.js';
import type { EarningsDeps } from './earnings_ports.js';

function sameItem(a: EarningItem | undefined, b: EarningItem): boolean {
  if (a === undefined) return false;
  const strip = (i: EarningItem): string =>
    JSON.stringify(Object.entries(i).filter(([k]) => k !== 'updatedAt').sort(([x], [y]) => x.localeCompare(y)));
  return strip(a) === strip(b);
}

export async function refreshEarnings(
  deps: EarningsDeps,
  input: { payeeId: string; paymentIds: readonly string[] },
): Promise<EarningsSummary> {
  const { payeeId, paymentIds } = input;
  return deps.store.runTransaction(async (tx) => {
    const now = deps.clock.now();
    const existing = new Map((await tx.listItems(payeeId)).map((i) => [i.id, i]));
    const next = new Map(existing);
    for (const id of new Set(paymentIds)) {
      const p = await tx.getPayment(id);
      if (p !== null && p.payeeId !== payeeId) continue;
      const subject = p === null ? null : await tx.getSubject(p);
      const item =
        p === null || subject === null
          ? null
          : earningItemOf({
              payment: p,
              refunded: await tx.refundedTotal(id),
              subject,
              payout: p.payoutId ? await tx.getPayout(p.payoutId) : null,
              now,
            });
      if (item === null) next.delete(id);
      else next.set(id, item);
    }
    const summary = summarizeEarnings(payeeId, [...next.values()], await tx.latestPayout(payeeId), now);
    for (const id of existing.keys()) if (!next.has(id)) tx.deleteItem(payeeId, id);
    for (const [id, item] of next) if (!sameItem(existing.get(id), item)) tx.putItem(item);
    tx.putSummary(summary);
    return summary;
  });
}
