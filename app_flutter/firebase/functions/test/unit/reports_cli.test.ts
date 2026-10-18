import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { parseArgs, executeTakedown } from '../../tools/reports.js';
import type { Report, ReportDeps } from '@photobooking/domain';

describe('reports CLI', () => {
  it('parseArgs list/show/dismiss/takedown', () => {
    // list default
    assert.deepEqual(parseArgs(['list']), {
      command: 'list',
      id: null,
      status: 'open',
      note: null,
      actor: null,
    });

    // list status
    assert.deepEqual(parseArgs(['list', 'actioned']), {
      command: 'list',
      id: null,
      status: 'actioned',
      note: null,
      actor: null,
    });

    // show
    assert.deepEqual(parseArgs(['show', 'rep_123']), {
      command: 'show',
      id: 'rep_123',
      status: 'open',
      note: null,
      actor: null,
    });

    // dismiss
    assert.deepEqual(parseArgs(['dismiss', 'rep_123', 'Lý do không hợp lệ', '--actor', 'staff_1']), {
      command: 'dismiss',
      id: 'rep_123',
      status: 'open',
      note: 'Lý do không hợp lệ',
      actor: 'staff_1',
    });

    // takedown
    assert.deepEqual(parseArgs(['takedown', 'rep_123', 'Vi phạm bản quyền', '--actor', 'staff_1']), {
      command: 'takedown',
      id: 'rep_123',
      status: 'open',
      note: 'Vi phạm bản quyền',
      actor: 'staff_1',
    });
  });

  it('dismiss and takedown need a note and --actor', () => {
    assert.throws(
      () => parseArgs(['dismiss', 'rep_123', '--actor', 'staff_1']),
      /note must be at least 5 characters/,
    );

    assert.throws(
      () => parseArgs(['dismiss', 'rep_123', '1234', '--actor', 'staff_1']),
      /note must be at least 5 characters/,
    );

    assert.throws(
      () => parseArgs(['dismiss', 'rep_123', 'Ghi chú hợp lệ']),
      /--actor <uid> is required for decisions/,
    );
  });

  it('takedown of an event target prints the S12.03 instruction and changes nothing', async () => {
    const report: Report = {
      id: 'rep_ev',
      reporterId: 'u1',
      targetType: 'event',
      targetId: 'ev_123',
      chatId: null,
      targetOwnerId: 'host_1',
      reason: 'spam',
      text: null,
      blocked: false,
      snapshot: { name: 'Event', excerpt: null, imageUrl: null },
      status: 'open',
      staffNote: null,
      decidedBy: null,
      decidedAt: null,
      createdAt: '2026-10-07T10:00:00.000Z',
    };

    const msg = await executeTakedown(report, 'staff_1', 'Lý do gỡ sự kiện', {} as ReportDeps);
    assert.match(msg, /Cancel it in S12.03 with an admin account/);
  });
});
