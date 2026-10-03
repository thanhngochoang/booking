import type { Clock, IdGenerator } from '../../src/ports.js';
import { MemoryChatStore } from '../../src/memory_chat_store.js';
import type { ChatDeps, PhotographerInquiryReader } from '../../src/chat_ports.js';

export class FakeClock implements Clock {
  constructor(private currentTime: Date = new Date('2026-10-01T12:00:00.000Z')) {}

  now(): Date {
    return new Date(this.currentTime.getTime());
  }

  advance(ms: number): void {
    this.currentTime = new Date(this.currentTime.getTime() + ms);
  }

  set(time: Date): void {
    this.currentTime = new Date(time.getTime());
  }
}

export class FakeIdGenerator implements IdGenerator {
  private counter = 1;

  newId(): string {
    return `id_${this.counter++}`;
  }
}

export class FakePhotographerInquiryReader implements PhotographerInquiryReader {
  private disabled = new Set<string>();

  disableInquiries(photographerId: string): void {
    this.disabled.add(photographerId);
  }

  enableInquiries(photographerId: string): void {
    this.disabled.delete(photographerId);
  }

  async acceptsInquiries(photographerId: string): Promise<boolean> {
    return !this.disabled.has(photographerId);
  }
}

export function createChatWorld(): {
  deps: ChatDeps;
  clock: FakeClock;
  ids: FakeIdGenerator;
  chats: MemoryChatStore;
  photographers: FakePhotographerInquiryReader;
} {
  const clock = new FakeClock();
  const ids = new FakeIdGenerator();
  const chats = new MemoryChatStore();
  const photographers = new FakePhotographerInquiryReader();
  const deps: ChatDeps = {
    chats,
    photographers,
    clock,
    ids,
  };
  return { deps, clock, ids, chats, photographers };
}
