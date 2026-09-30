package com.paditech.mvpbase.common.view;

import android.content.Context;
import android.support.annotation.Nullable;
import android.support.v7.widget.GridLayoutManager;
import android.support.v7.widget.LinearLayoutManager;
import android.support.v7.widget.RecyclerView;
import android.support.v7.widget.StaggeredGridLayoutManager;
import android.util.AttributeSet;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.view.animation.AccelerateDecelerateInterpolator;
import android.view.animation.AlphaAnimation;
import android.view.animation.Animation;
import android.view.animation.AnimationSet;

import com.paditech.mvpbase.R;

import java.util.List;

/**
 * Created by NhaPCS on 28/03/2017.
 */

public class LoadMoreRecyclerView extends RecyclerView {
    private static final int TYPE_FOOTER = 10001;
    private static final int DURATION = 400;
    private View mLoadMoreView;
    private boolean mIsLoading = false;
    private WrapAdapter mWrapAdapter;
    private DataObserver mDataObserver = new DataObserver();
    private LoadMoreListener mLoadMoreListener;
    private AnimationSet mAnimationVisible, mAnimationGone;

    public LoadMoreRecyclerView(Context context) {
        this(context, null);
    }

    public LoadMoreRecyclerView(Context context, @Nullable AttributeSet attrs) {
        this(context, attrs, 0);
    }

    public LoadMoreRecyclerView(Context context, @Nullable AttributeSet attrs, int defStyle) {
        super(context, attrs, defStyle);
        init();
    }

    public void setLoadMoreListener(LoadMoreListener listener) {
        this.mLoadMoreListener = listener;
    }

    private void init() {
        AlphaAnimation alphaAnimation = new AlphaAnimation(1, 0);
        mAnimationGone = new AnimationSet(true);
        mAnimationGone.setDuration(DURATION);
        mAnimationGone.setFillAfter(true);
        mAnimationGone.setInterpolator(new AccelerateDecelerateInterpolator());
        mAnimationGone.addAnimation(alphaAnimation);
        mAnimationGone.setAnimationListener(new Animation.AnimationListener() {
            @Override
            public void onAnimationStart(Animation animation) {
            }

            @Override
            public void onAnimationEnd(Animation animation) {
                mLoadMoreView.setVisibility(GONE);
            }

            @Override
            public void onAnimationRepeat(Animation animation) {

            }
        });


        AlphaAnimation alphaAnimation1 = new AlphaAnimation(0, 1);
        mAnimationVisible = new AnimationSet(true);
        mAnimationVisible.setDuration(DURATION);
        mAnimationVisible.setFillAfter(true);
        mAnimationVisible.setInterpolator(new AccelerateDecelerateInterpolator());
        mAnimationVisible.addAnimation(alphaAnimation1);
        mAnimationVisible.setAnimationListener(new Animation.AnimationListener() {
            @Override
            public void onAnimationStart(Animation animation) {
                mLoadMoreView.setVisibility(VISIBLE);
            }

            @Override
            public void onAnimationEnd(Animation animation) {

            }

            @Override
            public void onAnimationRepeat(Animation animation) {

            }
        });

    }

    public void setLoadMoreView(View loadMore) {
        this.mLoadMoreView = loadMore;
    }

    public void onLoadMoreComplete() {
        try {
            if (mWrapAdapter != null && mIsLoading) {
                //mWrapAdapter.notifyDataSetChanged();
                mLoadMoreView.startAnimation(mAnimationGone);
                mIsLoading = false;
            }
        } catch (Exception e) {
            e.printStackTrace();
        }
    }

    @Override
    public void setAdapter(Adapter adapter) {
        mWrapAdapter = new WrapAdapter(adapter);
        super.setAdapter(mWrapAdapter);
        adapter.registerAdapterDataObserver(mDataObserver);
        mDataObserver.onChanged();
    }

    @Override
    public Adapter getAdapter() {
        if (mWrapAdapter != null)
            return mWrapAdapter.getOriginalAdapter();
        return null;
    }

    @Override
    public void setLayoutManager(LayoutManager layout) {
        super.setLayoutManager(layout);
        if (mWrapAdapter != null) {
            if (layout instanceof GridLayoutManager) {
                final GridLayoutManager gridLayoutManager = (GridLayoutManager) layout;
                gridLayoutManager.setSpanSizeLookup(new GridLayoutManager.SpanSizeLookup() {
                    @Override
                    public int getSpanSize(int position) {
                        return mWrapAdapter.isFooter(position) ? gridLayoutManager.getSpanCount() : 1;
                    }
                });
            }
        }
    }

    @Override
    public void onScrollStateChanged(int state) {
        super.onScrollStateChanged(state);
        if (state == SCROLL_STATE_IDLE && mLoadMoreListener != null && !mIsLoading) {
            LayoutManager layoutManager = getLayoutManager();
            int lastVisibleItemPosition = 0;
            if (layoutManager instanceof GridLayoutManager) {
                lastVisibleItemPosition = ((GridLayoutManager) layoutManager).findLastVisibleItemPosition();
            } else if (layoutManager instanceof LinearLayoutManager) {
                lastVisibleItemPosition = ((LinearLayoutManager) layoutManager).findLastVisibleItemPosition();
            } else if (layoutManager instanceof StaggeredGridLayoutManager) {
                int[] into = new int[((StaggeredGridLayoutManager) layoutManager).getSpanCount()];
                ((StaggeredGridLayoutManager) layoutManager).findLastVisibleItemPositions(into);
                lastVisibleItemPosition = findMax(into);
            }

            if (layoutManager.getChildCount() > 0 &&
                    lastVisibleItemPosition >= layoutManager.getItemCount() - 1 &&
                    layoutManager.getItemCount() > layoutManager.getChildCount()) {
                mIsLoading = true;
                LoadMoreRecyclerView.this.post(new Runnable() {
                    @Override
                    public void run() {
                        mWrapAdapter.notifyDataSetChanged();
                    }
                });
                mLoadMoreView.startAnimation(mAnimationVisible);
                smoothScrollToPosition(mWrapAdapter.getItemCount() + 1);
                mLoadMoreListener.onLoadMore();
            }
        }
    }

    private int findMax(int[] lastPositions) {
        int max = lastPositions[0];
        for (int value : lastPositions) {
            if (value > max) {
                max = value;
            }
        }
        return max;
    }

    private class WrapAdapter extends RecyclerView.Adapter<ViewHolder> {

        private Adapter<ViewHolder> adapter;

        public WrapAdapter(Adapter<ViewHolder> adapter) {
            this.adapter = adapter;
        }

        public Adapter<ViewHolder> getOriginalAdapter() {
            return this.adapter;
        }


        public boolean isFooter(int position) {
            return position == getItemCount() - 1;
        }

        @Override
        public RecyclerView.ViewHolder onCreateViewHolder(ViewGroup parent, int viewType) {
            if (viewType == TYPE_FOOTER) {
                mLoadMoreView = LayoutInflater.from(getContext()).inflate(R.layout.view_loadmore, parent, false);
                return new SimpleViewHolder(mLoadMoreView);
            }
            return adapter.onCreateViewHolder(parent, viewType);
        }

        @Override
        public void onBindViewHolder(RecyclerView.ViewHolder holder, int position) {
            if (adapter != null) {
                if (position < adapter.getItemCount()) {
                    adapter.onBindViewHolder(holder, position);
                }
            }
        }

        // some times we need to override this
        @Override
        public void onBindViewHolder(RecyclerView.ViewHolder holder, int position, List<Object> payloads) {
            int adapterCount;
            if (adapter != null) {
                adapterCount = adapter.getItemCount();
                if (position < adapterCount) {
                    if (payloads.isEmpty()) {
                        adapter.onBindViewHolder(holder, position);
                    } else {
                        adapter.onBindViewHolder(holder, position, payloads);
                    }
                }
            }
        }

        @Override
        public int getItemCount() {
            if (adapter != null) {
                int count = adapter.getItemCount();
                if (count > 0) return adapter.getItemCount() + 1;
            }
            return 1;
        }

        @Override
        public int getItemViewType(int position) {
            if (isFooter(position)) {
                return TYPE_FOOTER;
            }
            int adapterCount;
            if (adapter != null) {
                adapterCount = adapter.getItemCount();
                if (position < adapterCount) {
                    return adapter.getItemViewType(position);
                }
            }
            return super.getItemViewType(position);
        }

        @Override
        public long getItemId(int position) {
            if (adapter != null && position >= 1) {
                if (position < adapter.getItemCount()) {
                    return adapter.getItemId(position);
                }
            }
            return super.getItemId(position);
        }

        @Override
        public void onAttachedToRecyclerView(RecyclerView recyclerView) {
            super.onAttachedToRecyclerView(recyclerView);
            RecyclerView.LayoutManager manager = recyclerView.getLayoutManager();
            if (manager instanceof GridLayoutManager) {
                final GridLayoutManager gridManager = ((GridLayoutManager) manager);
                gridManager.setSpanSizeLookup(new GridLayoutManager.SpanSizeLookup() {
                    @Override
                    public int getSpanSize(int position) {
                        return isFooter(position) ? gridManager.getSpanCount() : 1;
                    }
                });
            }
            adapter.onAttachedToRecyclerView(recyclerView);
        }

        @Override
        public void onDetachedFromRecyclerView(RecyclerView recyclerView) {
            adapter.onDetachedFromRecyclerView(recyclerView);
        }

        @Override
        public void onViewAttachedToWindow(RecyclerView.ViewHolder holder) {
            super.onViewAttachedToWindow(holder);
            ViewGroup.LayoutParams lp = holder.itemView.getLayoutParams();
            if (lp != null
                    && lp instanceof StaggeredGridLayoutManager.LayoutParams
                    && isFooter(holder.getLayoutPosition())) {
                StaggeredGridLayoutManager.LayoutParams p = (StaggeredGridLayoutManager.LayoutParams) lp;
                p.setFullSpan(true);
            }
            adapter.onViewAttachedToWindow(holder);
        }

        @Override
        public void onViewDetachedFromWindow(RecyclerView.ViewHolder holder) {
            adapter.onViewDetachedFromWindow(holder);
        }

        @Override
        public void onViewRecycled(RecyclerView.ViewHolder holder) {
            adapter.onViewRecycled(holder);
        }

        @Override
        public boolean onFailedToRecycleView(RecyclerView.ViewHolder holder) {
            return adapter.onFailedToRecycleView(holder);
        }

        @Override
        public void unregisterAdapterDataObserver(AdapterDataObserver observer) {
            adapter.unregisterAdapterDataObserver(observer);
        }

        @Override
        public void registerAdapterDataObserver(AdapterDataObserver observer) {
            adapter.registerAdapterDataObserver(observer);
        }

        private class SimpleViewHolder extends RecyclerView.ViewHolder {
            public SimpleViewHolder(View itemView) {
                super(itemView);
            }
        }
    }

    private class DataObserver extends RecyclerView.AdapterDataObserver {
        @Override
        public void onChanged() {
            if (mWrapAdapter != null) {
                mWrapAdapter.notifyDataSetChanged();
            }
            if (mWrapAdapter != null) {
                int emptyCount = 0;
                emptyCount++;
                if (mWrapAdapter.getItemCount() == emptyCount) {
                    LoadMoreRecyclerView.this.setVisibility(View.GONE);
                } else {
                    LoadMoreRecyclerView.this.setVisibility(View.VISIBLE);
                }
            }
        }

        @Override
        public void onItemRangeInserted(int positionStart, int itemCount) {
            mWrapAdapter.notifyItemRangeInserted(positionStart, itemCount);
        }

        @Override
        public void onItemRangeChanged(int positionStart, int itemCount) {
            mWrapAdapter.notifyItemRangeChanged(positionStart, itemCount);
        }

        @Override
        public void onItemRangeChanged(int positionStart, int itemCount, Object payload) {
            mWrapAdapter.notifyItemRangeChanged(positionStart, itemCount, payload);
        }

        @Override
        public void onItemRangeRemoved(int positionStart, int itemCount) {
            mWrapAdapter.notifyItemRangeRemoved(positionStart, itemCount);
        }

        @Override
        public void onItemRangeMoved(int fromPosition, int toPosition, int itemCount) {
            mWrapAdapter.notifyItemMoved(fromPosition, toPosition);
        }
    }

    public interface LoadMoreListener {
        void onLoadMore();
    }
}
