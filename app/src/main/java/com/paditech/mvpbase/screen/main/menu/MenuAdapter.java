package com.paditech.mvpbase.screen.main.menu;

import androidx.recyclerview.widget.RecyclerView;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.TextView;

import com.paditech.mvpbase.R;

import butterknife.BindView;
import butterknife.ButterKnife;

/**
 * Created by ThanhNgocHoang on 11/8/2017.
 */

public class MenuAdapter extends RecyclerView.Adapter<RecyclerView.ViewHolder> {

    private OnMenuSelectListener mOnMenuSelectListener;
    private boolean isPhotographer;
    private int countMess, mCountCalendar;

    public MenuAdapter(boolean isPhotographer) {
        this.isPhotographer = isPhotographer;
    }

    public void setCountMess(int count) {
        this.countMess = count;
        notifyDataSetChanged();
    }

    public void setmCountCalendar(int count) {
        this.mCountCalendar = count;
        notifyDataSetChanged();
    }


    public void setmOnMenuSelectListener(OnMenuSelectListener mOnMenuSelectListener) {
        this.mOnMenuSelectListener = mOnMenuSelectListener;
    }

    @Override
    public RecyclerView.ViewHolder onCreateViewHolder(ViewGroup parent, int viewType) {
        // lay view item cua 1 chuc nang trong menu
        View view = LayoutInflater.from(parent.getContext()).inflate(R.layout.item_menu, parent, false);
        return new MenuHolder(view);
    }

    @Override
    public void onBindViewHolder(RecyclerView.ViewHolder holder, int position) {
        MenuHolder menuHolder = (MenuHolder) holder;
        menuHolder.bindData(position);
    }

    @Override
    public int getItemCount() {
        if (isPhotographer) return MenuType.PhotographerMenu.values().length;
        return MenuType.UserMenu.values().length;
    }

    protected class MenuHolder extends RecyclerView.ViewHolder {
        @BindView(R.id.tv_name)
        TextView tvName;
        @BindView(R.id.item_layout)
        View itemLayout;
        @BindView(R.id.tv_badge)
        TextView tvBadge;

        public MenuHolder(View itemView) {
            super(itemView);
            ButterKnife.bind(this, itemView);
        }

        private void bindData(final int pos) {
            if (isPhotographer) {
                MenuType.PhotographerMenu photographerMenu = MenuType.PhotographerMenu.values()[pos];
                tvName.setText(photographerMenu.getText());
                switch (photographerMenu) {
                    case MESSAGES:
                        if (countMess > 0) {
                            tvBadge.setVisibility(View.VISIBLE);
                            tvBadge.setText(String.valueOf(countMess));
                        } else tvBadge.setVisibility(View.GONE);
                        break;
                    case CALENDAR:
                        if (mCountCalendar > 0) {
                            tvBadge.setVisibility(View.VISIBLE);
                            tvBadge.setText(String.valueOf(mCountCalendar));
                        } else tvBadge.setVisibility(View.GONE);
                        break;
                    default:
                        tvBadge.setVisibility(View.GONE);
                        break;
                }
                itemView.setOnClickListener(new View.OnClickListener() {
                    @Override
                    public void onClick(View view) {
                        if (mOnMenuSelectListener != null)
                            mOnMenuSelectListener.onSelectedPhotographerMenu(MenuType.PhotographerMenu.values()[pos]);
                    }
                });
            } else {
                MenuType.UserMenu userMenu = MenuType.UserMenu.values()[pos];
                tvName.setText(userMenu.getText());
                switch (userMenu) {
                    case MESSAGES:
                        if (countMess > 0) {
                            tvBadge.setVisibility(View.VISIBLE);
                            tvBadge.setText(String.valueOf(countMess));
                        } else tvBadge.setVisibility(View.GONE);
                        break;
                    case CALENDAR:
                        if (mCountCalendar > 0) {
                            tvBadge.setVisibility(View.VISIBLE);
                            tvBadge.setText(String.valueOf(mCountCalendar));
                        } else tvBadge.setVisibility(View.GONE);
                        break;
                    default:
                        tvBadge.setVisibility(View.GONE);
                        break;
                }
                itemView.setOnClickListener(new View.OnClickListener() {
                    @Override
                    public void onClick(View view) {
                        if (mOnMenuSelectListener != null)
                            mOnMenuSelectListener.onSelectedUserMenu(MenuType.UserMenu.values()[pos]);
                    }
                });
            }
        }
    }

    public interface OnMenuSelectListener {
        void onSelectedPhotographerMenu(MenuType.PhotographerMenu menuType);

        void onSelectedUserMenu(MenuType.UserMenu menuType);

    }
}
