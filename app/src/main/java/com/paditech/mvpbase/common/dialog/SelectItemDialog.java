package com.paditech.mvpbase.common.dialog;

import android.support.v4.app.FragmentManager;
import android.support.v7.widget.DividerItemDecoration;
import android.support.v7.widget.LinearLayoutManager;
import android.support.v7.widget.RecyclerView;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.TextView;

import com.paditech.mvpbase.R;
import com.paditech.mvpbase.common.base.BaseBottomDialog;
import com.paditech.mvpbase.common.model.PriceEnum;
import com.paditech.mvpbase.common.utils.StringUtil;

import butterknife.BindView;

/**
 * Created by ThanhNgocHoang on 12/21/2017.
 */

public class SelectItemDialog extends BaseBottomDialog {
    @BindView(R.id.tv_title)
    TextView tvTitle;
    @BindView(R.id.recycler_view)
    RecyclerView recyclerView;

    private String title;
    private OnSelectPriceListener mOnSelectPriceListener;
    private OnSelectRangePriceListener mOnSelectRangePriceListener;
    private boolean isSelectRangePrice;

    public static void show(FragmentManager manager, String title, OnSelectPriceListener listener) {
        SelectItemDialog selectItemDialog = new SelectItemDialog();
        selectItemDialog.mOnSelectPriceListener = listener;
        selectItemDialog.title = title;
        selectItemDialog.show(manager, selectItemDialog.getClass().getSimpleName());
    }


    public static void show(FragmentManager manager, String title, OnSelectRangePriceListener listener) {
        SelectItemDialog selectItemDialog = new SelectItemDialog();
        selectItemDialog.mOnSelectRangePriceListener = listener;
        selectItemDialog.title = title;
        selectItemDialog.isSelectRangePrice = true;
        selectItemDialog.show(manager, selectItemDialog.getClass().getSimpleName());
    }


    @Override
    protected int getContentView() {
        return R.layout.dialog_list_item;
    }

    @Override
    protected void initView(View view) {
        if (!StringUtil.isEmpty(title)) {
            tvTitle.setVisibility(View.VISIBLE);
            tvTitle.setText(title);
        } else tvTitle.setVisibility(View.GONE);
        recyclerView.setLayoutManager(new LinearLayoutManager(getContext()));
        recyclerView.addItemDecoration(new DividerItemDecoration(getContext(), DividerItemDecoration.VERTICAL));
        recyclerView.setAdapter(new TextAdapter());
    }

    private class TextAdapter extends RecyclerView.Adapter<RecyclerView.ViewHolder> {
        private final long[] DATA = new long[]{200000, 300000, 500000, 700000, 1000000};

        @Override
        public RecyclerView.ViewHolder onCreateViewHolder(ViewGroup parent, int viewType) {
            return new TextHolder(LayoutInflater.from(parent.getContext()).inflate(R.layout.item_text_select, parent, false));
        }

        @Override
        public void onBindViewHolder(RecyclerView.ViewHolder holder, final int position) {
            TextView textView = (TextView) holder.itemView;
            if (isSelectRangePrice) {
                textView.setText(PriceEnum.values()[position].getText());
                textView.setOnClickListener(new View.OnClickListener() {
                    @Override
                    public void onClick(View v) {
                        if (mOnSelectRangePriceListener != null)
                            mOnSelectRangePriceListener.onSelectPrice(PriceEnum.values()[position]);
                        dismiss();
                    }
                });
            } else {
                if (position == getItemCount() - 1) {
                    textView.setText(R.string.other_price);
                    textView.setOnClickListener(new View.OnClickListener() {
                        @Override
                        public void onClick(View v) {
                            EnterPriceDialog.show(getFragmentManager(), mOnSelectPriceListener);
                            dismiss();
                        }
                    });
                } else {
                    textView.setText(StringUtil.getPriceVNDCurrency(DATA[position]));
                    textView.setOnClickListener(new View.OnClickListener() {
                        @Override
                        public void onClick(View v) {
                            if (mOnSelectPriceListener != null)
                                mOnSelectPriceListener.onSelectPrice(DATA[position]);
                            dismiss();
                        }
                    });
                }
            }
        }

        @Override
        public int getItemCount() {
            if (isSelectRangePrice) return PriceEnum.values().length;
            else return DATA.length + 1;
        }
    }

    private class TextHolder extends RecyclerView.ViewHolder {

        TextHolder(View itemView) {
            super(itemView);
        }
    }

    public interface OnSelectPriceListener {
        void onSelectPrice(long price);
    }

    public interface OnSelectRangePriceListener {
        void onSelectPrice(PriceEnum price);
    }
}
